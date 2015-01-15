class Launch
  require 'oauth/request_proxy/rack_request'
  attr_reader :params, :errors, :tool, :user, :activity, :section, :session, :parent_section
	def initialize(request, params)
    @params = params['launch_params'] || params
    @request = request
    @errors = []
    @tool = nil
    authorize!
    @user = find_user
    @duplicate_section_data = {} 
    @section = find_section
    @activity = find_activity
  end

  def authorize!
    return self if @tool
    if key = @params['oauth_consumer_key']
      if secret = oauth_shared_secrets[key]
        @tool = IMS::LTI::ToolProvider.new(key, secret, @params)
      else
        @tool = IMS::LTI::ToolProvider.new(nil, nil, @params)
        @tool.lti_msg = "Your consumer didn't use a recognized key."
        @tool.lti_errorlog = "You did it wrong!"
        @errors << "Consumer key wasn't recognized"
        return self
      end
    else
      @errors << "No consumer key"
      return self
    end

    if !@tool.valid_request?(@request)
      @errors << "The OAuth signature was invalid"
      return self
    end
    unless Rails.env == "development"
      if Time.now.utc.to_i - @tool.request_oauth_timestamp.to_i > 4.hours
        @errors << "Your request is too old."
        return self
      end
    end
    self
  end

  def lti_roles_to_ocill_user_role(lti_roles)
    roles = lti_roles.split(',') if lti_roles 
    if roles.include?("Instructor")
      "Instructor"
    elsif roles.grep(/TeachingAssistant/).any?
      "Instructor"  
    elsif roles.include?("Learner")
      "Learner"      
    else
      error_message = "The Launch model just created a new user as a Learner, even though the user was not properly identified"
      LoggingMailer.log_email(error_message: error_message, roles: roles,  parameters: @params ).deliver
      "Learner" 
    end 
  end

  def unauthorized?
    !authorized?  
  end
  
  def authorized?
    return @errors.empty? if @tool
    authorize!
    @errors.empty?
  end

  def instructor_view_drill?
    user.role == "Instructor" && self.activity.present? && self.activity.drill.present?
  end

  def instructor_pick_course?
    user.role == "Instructor" && self.activity.present? && self.section.present?
  end  
  
  def instructor_pick_drill?
    user.role == "Instructor" && self.activity.present? && self.activity.drill.present?
  end
  
  def learner_attempt_drill?
    user.role == "Learner" && self.activity.drill.present? && Role.find_or_create_by_user_id_and_course_id_and_name(user.id, self.activity.course, user.role)
  end

  def find_user
    role = lti_roles_to_ocill_user_role(params[:roles])
    email = "user#{rand(10000..999999999999).to_s}@example.com"
    password = "pass#{rand(10000..999999999999).to_s}"
    u = User.find_or_create_by_lti_user_id(lti_user_id: params[:user_id], role: role, email: email, password: password)
  end

  def canvas_course_id
    referrer_uri = URI.parse(@request.referrer)
    path_parts = referrer_uri.path.split("/")
    course_id_index = path_parts.find_index("courses") + 1
    course_id = path_parts[course_id_index]
  end


  def find_section
    if params['custom_canvas_course_id']
      # look for a section that matches the actual course id of this course
      the_section = Section.find_by_lti_course_id(params[:context_id])
      # if there is one, then this course has already been created and populated, so just go ahead and continue
      if the_section 
        # return because you are done
        return the_section
      else # if the section doesn't exist
          # try to find the parent 

        parent_section = Section.find_by_canvas_course_id(params['custom_canvas_course_id'])

        if parent_section
          # if there is a real course to copy, store it in @duplicate_section_data and return nil
            
            @duplicate_section_data = { 
              parent_section_id:       parent_section.id,
              canvas_course_id:   canvas_course_id, # this is the current course
              lti_course_id:        params[:context_id],
              parent_canvas_course_id:    parent_section.parent.canvas_course_id
            }
            # return nil
          return the_section = nil
        else
          # throw an error because they are trying to copy from a section that doesn;t exist
          # Tell the user that the custom parent course id that is set isn't correct.  Refer them to the site administrator
        end
      end
    else
      the_section = Section.where(lti_course_id: params[:context_id]).first_or_create do |section|
        section.lti_course_id = params[:context_id]
        section.canvas_course_id = canvas_course_id
      end
    end

    if the_section.canvas_course_id != canvas_course_id
      the_section.canvas_course_id = canvas_course_id
      the_section.save!       
    end
    the_section
  end
  
  def find_activity
    the_activity = Activity.find_or_create_by_lti_resource_link_id(lti_resource_link_id: params[:resource_link_id], section_id: section.id)
  end

private
  def oauth_shared_secrets
    secrets = {}
    key_values_array = ENV["OAUTH_SHARED_SECRETS"].split(",")
    key_values_array.each do |pair|
      k,v = pair.split("=>")
      secrets[k] = v
    end
    secrets
  end
end