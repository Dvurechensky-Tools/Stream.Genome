defmodule StreamGenomeWeb.Router do
  use StreamGenomeWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {StreamGenomeWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin do
    plug StreamGenomeWeb.Plugs.AdminAuth
  end

  scope "/", StreamGenomeWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/admin", StreamGenomeWeb do
    pipe_through [:browser, :admin]

    get "/", AdminController, :index
    post "/crawler-settings", AdminController, :update_crawler_settings
    post "/ai-settings", AdminController, :update_ai_settings
    post "/youtube-cookies", AdminController, :save_youtube_cookies
    get "/sources/:id", AdminSourceController, :show
    post "/sources/:id/scan", AdminSourceController, :scan
    post "/sources/:id/transcripts", AdminSourceController, :transcripts
    post "/sources/:id/transcripts/auto", AdminSourceController, :auto_transcripts
    post "/sources/:id/transcripts/retry-failed", AdminSourceController, :retry_failed_transcripts
    post "/sources/:id/intelligence/windows", AdminSourceController, :intelligence_windows
    post "/sources/:id/intelligence/auto", AdminSourceController, :auto_intelligence
    post "/sources/:id/intelligence/project", AdminSourceController, :project_intelligence
    get "/ingest", IngestController, :new
    post "/ingest", IngestController, :create
    get "/youtube/channel", YouTubeChannelController, :new
    post "/youtube/channel", YouTubeChannelController, :create
  end

  # Other scopes may use custom stacks.
  # scope "/api", StreamGenomeWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:stream_genome, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: StreamGenomeWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
