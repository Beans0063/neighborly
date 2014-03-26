# coding: utf-8
class ProjectsController < ApplicationController
  include SimpleCaptcha::ControllerHelpers

  after_filter :verify_authorized, except: [:index, :video, :video_embed, :embed,
                                            :embed_panel, :comments, :budget,
                                            :reward_contact, :send_reward_email,
                                            :start]

  inherit_resources
  defaults finder: :find_by_permalink!
  actions :create, :edit, :update
  respond_to :html

  def new
    @project = Project.new(user: current_user)
    authorize @project
  end

  def index
    used_ids = [0]
    @featured = Project.with_state('online').featured.limit(1).first
    used_ids << @featured.id if @featured

    @recommended = Project.with_state('online').recommended.home_page.limit(5).where('id NOT IN (?)', used_ids)
    used_ids += @recommended.map(&:id) if @recommended

    @successful = Project.visible.successful.home_page.limit(4)
    @ending_soon = Project.expiring.home_page.where('id NOT IN (?)', used_ids).limit(4)
    @coming_soon = Project.soon.home_page.limit(4)
    @channels = Channel.with_state('online').order('RANDOM()').limit(4)
    @press_assets = PressAsset.order('created_at DESC').limit(5)
  end

  def create
    @project = Project.new(permitted_params[:project].merge(user: current_user))
    authorize @project
    create! { success_project_path(@project) }
  end

  def send_to_analysis
    authorize resource
    resource.send_to_analysis
    flash.notice = t('projects.send_to_analysis')
    redirect_to project_path(@project)
  end

  def success
    authorize resource
  end

  def edit
    authorize resource
    edit!
  end

  def update
    authorize resource
    update! { edit_project_path(@project) }
  end

  def show
    authorize resource
    fb_admins_add(resource.user.facebook_id) if resource.user.facebook_id
    render :about if request.xhr?
  end

  def comments
    @project = resource
  end

  def reports
    authorize resource
  end

  def budget
    @project = resource
  end

  def video
    project = Project.new(video_url: params[:url])
    render json: project.video.to_json
  rescue VideoInfo::UrlError
    render json: nil
  end

  %w(embed video_embed).each do |method_name|
    define_method method_name do
      @title = resource.name
      render layout: 'embed'
    end
  end

  def embed_panel
    @project = resource
    render layout: !request.xhr?
  end

  def send_reward_email
    if simple_captcha_valid?
      ProjectsMailer.contact_about_reward_email(params, resource).deliver
      flash.notice = I18n.t('controllers.projects.send_reward_email.success')
    else
      flash.alert  = I18n.t('controllers.projects.send_reward_email.error')
    end
    redirect_to project_path(resource)
  end

  def reward_contact
    render layout: !request.xhr?
  end

  def start
    @projects = Project.visible.successful.home_page.limit(3)
  end

  protected
  def permitted_params
    params.permit(policy(@project || Project).permitted_attributes)
  end
end
