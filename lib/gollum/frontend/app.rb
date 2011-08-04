require 'cgi'
require 'sinatra'
require 'gollum'
require 'mustache/sinatra'

require 'gollum/frontend/views/layout'
require 'gollum/frontend/views/editable'

module Precious
  class App < Sinatra::Base
    register Mustache::Sinatra

    dir = File.dirname(File.expand_path(__FILE__))

    # We want to serve public assets for now

    set :public,    "#{dir}/public"
    set :static,    true

    set :mustache, {
      # Tell mustache where the Views constant lives
      :namespace => Precious,

      # Mustache templates live here
      :templates => "#{dir}/templates",

      # Tell mustache where the views are
      :views => "#{dir}/views"
    }

    # Sinatra error handling
    configure :development, :staging do
      enable :show_exceptions, :dump_errors, :sessions
      disable :raise_errors, :clean_trace
    end

    configure :test do
      enable :logging, :raise_errors, :dump_errors, :sessions
    end

    get '/' do
      check_login
      show_page_or_file('Home')
    end

    get '/edit/*' do
      check_login
      @name = params[:splat].first
      wiki = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      if page = wiki.page(@name)
        @page = page
        @content = page.raw_data
        mustache :edit
      else
        mustache :create
      end
    end

    post '/edit/*' do
      check_login
      wiki = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      page = wiki.page(params[:splat].first)
      name = params[:rename] || page.name
      committer = Gollum::Committer.new(wiki, commit_message)
      commit    = {:committer => committer}

      update_wiki_page(wiki, page, params[:content], commit, name,
        params[:format])
      update_wiki_page(wiki, page.footer,  params[:footer],  commit) if params[:footer]
      update_wiki_page(wiki, page.sidebar, params[:sidebar], commit) if params[:sidebar]
      committer.commit

      redirect "/#{CGI.escape(Gollum::Page.cname(name))}"
    end

    post '/create' do
      check_login
      name = params[:page]
      wiki = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)

      format = params[:format].intern

      begin
        wiki.write_page(name, format, params[:content], commit_message)
        redirect "/#{CGI.escape(name)}"
      rescue Gollum::DuplicatePageError => e
        @message = "Duplicate page: #{e.message}"
        mustache :error
      end
    end

    post '/revert/:page/*' do
      check_login
      wiki  = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      @name = params[:page]
      @page = wiki.page(@name)
      shas  = params[:splat].first.split("/")
      sha1  = shas.shift
      sha2  = shas.shift

      if wiki.revert_page(@page, sha1, sha2, commit_message)
        redirect "/#{CGI.escape(@name)}"
      else
        sha2, sha1 = sha1, "#{sha1}^" if !sha2
        @versions = [sha1, sha2]
        diffs     = wiki.repo.diff(@versions.first, @versions.last, @page.path)
        @diff     = diffs.first
        @message  = "The patch does not apply."
        mustache :compare
      end
    end

    post '/preview' do
      check_login
      wiki      = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      @name     = "Preview"
      @page     = wiki.preview_page(@name, params[:content], params[:format])
      @content  = @page.formatted_data
      @editable = false
      mustache :page
    end

    get '/history/:name' do
      check_login
      @name     = params[:name]
      wiki      = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      @page     = wiki.page(@name)
      @page_num = [params[:page].to_i, 1].max
      @versions = @page.versions :page => @page_num
      mustache :history
    end

    post '/compare/:name' do
      check_login
      @versions = params[:versions] || []
      if @versions.size < 2
        redirect "/history/#{CGI.escape(params[:name])}"
      else
        redirect "/compare/%s/%s...%s" % [
          CGI.escape(params[:name]),
          @versions.last,
          @versions.first]
      end
    end

    get '/compare/:name/:version_list' do
      check_login
      @name     = params[:name]
      @versions = params[:version_list].split(/\.{2,3}/)
      wiki      = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      @page     = wiki.page(@name)
      diffs     = wiki.repo.diff(@versions.first, @versions.last, @page.path)
      @diff     = diffs.first
      mustache :compare
    end

    get %r{^/(javascript|css|images)} do
      halt 404
    end

    get %r{/(.+?)/([0-9a-f]{40})} do
      check_login
      name = params[:captures][0]
      wiki = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      if page = wiki.page(name, params[:captures][1])
        @page = page
        @name = name
        @content = page.formatted_data
        @editable = true
        mustache :page
      else
        halt 404
      end
    end

    get '/search' do
      check_login
      @query = params[:q]
      wiki = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      @results = wiki.search @query
      @name = @query
      mustache :search
    end

    get '/pages' do
      check_login
      wiki = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      @results = wiki.pages
      @ref = wiki.ref
      mustache :pages
    end

    get '/login' do
      mustache :login
    end

    post '/login' do
      if Gollum::Auth.new.login(params[:userid])
        session[:name] = params[:userid]
        redirect '/'
      else
        redirect '/login'
      end
    end

    get '/*' do
      check_login
      show_page_or_file(params[:splat].first)
    end

    def show_page_or_file(name)
      wiki = Gollum::Wiki.new(settings.gollum_path, settings.wiki_options)
      if page = wiki.page(name)
        @page = page
        @name = name
        @content = page.formatted_data
        @editable = true
        mustache :page
      elsif file = wiki.file(name)
        content_type file.mime_type
        file.raw_data
      else
        @name = name
        mustache :create
      end
    end

    def update_wiki_page(wiki, page, content, commit_message, name = nil, format = nil)
      return if !page ||
        ((!content || page.raw_data == content) && page.format == format)
      name    ||= page.name
      format    = (format || page.format).to_sym
      content ||= page.raw_data
      wiki.update_page(page, name, format, content.to_s, commit_message)
    end

    def check_login
      unless session[:name]
        redirect '/login'
      end
    end

    def commit_message
      {
        :message => params[:message],
        :name => session[:name],
        :mail => '',
      }
    end
  end
end
