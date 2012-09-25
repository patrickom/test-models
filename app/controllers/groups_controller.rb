class GroupsController < ApplicationController
  
    respond_to :html, :json
  
    before_filter :authenticate_user!
    
  def index
    user_arel = User.arel_table
    @groups = Group.joins(:users).where( user_arel[:id].eq( current_user.id ) )
   
    respond_with @groups
  end
  
  def show
    @group = Group.find(params[:id])
    respond_with @group
  end

  def edit
    @group = Group.find(params[:id])
    respond_with(@group)
  end

  def update
    @group = Group.find(params[:id])
    # TODO delete group when deleting all users
    respond_with @group do |format|
      if @group.update_attributes(params[:group])
        flash[:notice] = t('flash.actions.update.notice', :resource_name => "Team")
      else
        format.html { render action: "edit" }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end

  end
  
  def new
    @group = Group.new
    respond_with @dyna_model
  end

  def create
    @group = Group.new(params[:group])
    @group.users << current_user
    respond_with @group do | format |
      if @group.save
        flash[:notice] = t('flash.actions.create.notice', :resource_name => "Team")
      else
        format.html { render action: "new" }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  
end
