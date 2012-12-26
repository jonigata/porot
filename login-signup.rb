namespace URL_PREFIX do
  before do
    unless
        [link_text('login/'), link_text('signup/')].include?(request.path_info) or 
        request.path_info =~ /\.css$/ or
        request.path_info =~ /^#{link_text('archive/')}/ or
        request.path_info =~ /^#{link_text('first_date/')}/ or
        request.path_info =~ /^#{link_text('last_date/')}/ or
        request.path_info =~ /^#{link_text('users/')}/ or
        request.path_info =~ /^#{link_text('latest')}/ or
        request.path_info =~ /^#{link_text('take/')}/ or
        @logged_in_user = User.find_by_id(session["user_id"])
      redirect to('/login/'), 303
    end
    puts "logged in as:#{@logged_in_user.username}" if @logged_in_user
  end

  get '/login/' do
    erb :login
  end

  post '/login/' do
    if user = User.find_by_username(params[:username]) and
	User.hash_pw(user.salt, params[:password]) == user.hashed_password
      session["user_id"] = user.id
      $stderr.puts("login ok")
      redirect to('/')
    else
      @login_error = "Incorrect username or password"
      $stderr.puts("login failed")
      erb :login
    end
  end

  post '/signup/' do
    if params[:username] !~ /^\w+$/
      @signup_error = "Username must only contain letters, numbers and underscores."
    elsif params[:username] == 'all'
      @signup_error = "That username is taken."
    elsif redis.exists("user:username:#{params[:username]}")
      @signup_error = "That username is taken."
    elsif params[:username].length < 4
      @signup_error = "Username must be at least 4 characters"
    elsif params[:password].length < 6
      @signup_error = "Password must be at least 6 characters!"
    elsif params[:password] != params[:password_confirmation]
      @signup_error = "Passwords do not match!"
    end
    if @signup_error
      erb :login
    else
      user = User.create(params[:username], params[:password])
      session["user_id"] = user.id
      redirect to("/")
    end
  end

  get '/logout/' do
    session["user_id"] = nil
    redirect to('/login/')
  end
end

