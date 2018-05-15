class SchoolCalendarsController < ApplicationController
  has_scope :page, default: 1
  has_scope :per, default: 10

  def index
    @school_calendars = apply_scopes(SchoolCalendar).includes(:unity)
                                                    .filter(filtering_params(params[:search]))
                                                    .ordered

    authorize @school_calendars

    @unities = Unity.ordered
  end

  def edit
    @school_calendar = resource

    authorize resource
  end

  def update
    resource.assign_attributes resource_params

    authorize resource

    if resource.save
      respond_with resource, location: school_calendars_path
    else
      render :edit
    end
  end

  def destroy
    authorize resource

    resource_destroyer = ResourceDestroyer.new.destroy(resource)

    if resource_destroyer.has_error?
      flash[:error] = resource_destroyer.error_message
      flash[:notice] = ""
    end

    respond_with resource, location: school_calendars_path
  end

  def history
    @school_calendar = SchoolCalendar.find(params[:id])

    authorize @school_calendar

    respond_with @school_calendar
  end

  def synchronize
    @school_calendars = SchoolCalendarsParser.parse!(IeducarApiConfiguration.current)

    authorize(SchoolCalendar, :create?)
    authorize(SchoolCalendar, :update?)
  end

  def create_and_update_batch
    begin
      school_calendars = SchoolCalendarsCreator.create!(params[:synchronize]) && SchoolCalendarsUpdater.update!(params[:synchronize])

      if school_calendars
        set_assigned_teacher_for_users(school_calendars)
        set_classroom_and_discipline_for_users(school_calendars)
        set_school_calendar_classroom_step

        redirect_to school_calendars_path, notice: t('.notice')
      else
        redirect_to synchronize_school_calendars_path, alert: t('.alert')
      end
    rescue SchoolCalendarsCreator::InvalidSchoolCalendarError => error
      redirect_to synchronize_school_calendars_path, alert: error.to_s
    rescue SchoolCalendarsCreator::InvalidClassroomCalendarError => error
      redirect_to synchronize_school_calendars_path, alert: error.to_s
    rescue SchoolCalendarsUpdater::InvalidSchoolCalendarError => error
      redirect_to synchronize_school_calendars_path, alert: error.to_s
    rescue SchoolCalendarsUpdater::InvalidClassroomCalendarError => error
      redirect_to synchronize_school_calendars_path, alert: error.to_s
    rescue
      redirect_to synchronize_school_calendars_path, alert: t('.alert')
    end
  end

  private

  def set_assigned_teacher_for_users(school_calendars)
    set_assigned_teacher_by_school_calendars(school_calendars)
    set_assigned_teacher_by_school_calendar_classrooms(school_calendars)
  end

  def set_assigned_teacher_by_school_calendars(school_calendars)
    school_calendars.each do |item|
      current_year = SchoolCalendar.by_unity_id(item[:unity_id]).by_school_day(Date.today).first.try(:year)

      User.by_current_unity_id(item[:unity_id]).each do |user|
        classrooms_in_school_calendar_classrooms = SchoolCalendarClassroom.joins(:classroom)
                                                                          .merge(Classroom.where(year: current_year))
                                                                          .map(&:classroom_id)
        teacher_current_classroom = TeacherDisciplineClassroom.joins(:classroom)
                                                              .merge(Classroom.where(year: current_year))
                                                              .where.not(classroom_id: classrooms_in_school_calendar_classrooms)
                                                              .where(teacher_id: user.assumed_teacher_id)

        if teacher_current_classroom.blank?
          user.update_column(:assumed_teacher_id, nil)
        end
      end
    end
  end

  def set_assigned_teacher_by_school_calendar_classrooms(school_calendars)
    school_calendars.each do |item|
      current_classroom_ids = SchoolCalendarClassroom.by_unity_id(item[:unity_id]).joins(:classroom_steps)
                                                     .merge(SchoolCalendarClassroomStep.by_school_day(Date.today))
                                                     .map(&:classroom_id)

      User.by_current_unity_id(item[:unity_id]).each do |user|
        teacher_current_classroom = TeacherDisciplineClassroom.where.not(classroom_id: current_classroom_ids)
                                                              .where(teacher_id: user.assumed_teacher_id)

        if teacher_current_classroom.blank? && SchoolCalendarClassroomStep.by_classroom(user.current_classroom_id).any?
          user.update_column(:assumed_teacher_id, nil)
        end
      end
    end
  end

  def set_classroom_and_discipline_for_users(school_calendars)
    set_classroom_and_discipline_by_school_calendars(school_calendars)
    set_classroom_and_discipline_by_school_calendar_classrooms(school_calendars)
  end

  def set_classroom_and_discipline_by_school_calendars(school_calendars)
    school_calendars.each do |item|
      current_year = SchoolCalendar.by_unity_id(item[:unity_id]).by_school_day(Date.today).first.try(:year)

      User.by_current_unity_id(item[:unity_id]).each do |user|
        classroom_year = Classroom.find_by_id(user.current_classroom_id).try(:year)

        if classroom_year && current_year != classroom_year && SchoolCalendarClassroomStep.by_classroom(user.current_classroom_id).empty?
          user.update_columns(
            current_classroom_id: nil,
            current_discipline_id: nil
          )
        end
      end
    end
  end

  def set_classroom_and_discipline_by_school_calendar_classrooms(school_calendars)
    school_calendars.each do |item|
      current_classroom_ids = SchoolCalendarClassroom.by_unity_id(item[:unity_id]).joins(:classroom_steps)
                                                     .merge(SchoolCalendarClassroomStep.by_school_day(Date.today))
                                                     .map(&:classroom_id)

      User.by_current_unity_id(item[:unity_id]).each do |user|
        exists_classroom_step = SchoolCalendarClassroomStep.by_classroom(user.current_classroom_id).any?

        if exists_classroom_step && !current_classroom_ids.include?(user.current_classroom_id)
          user.update_columns(
            current_classroom_id: nil,
            current_discipline_id: nil
          )
        end
      end
    end
  end

  def set_school_calendar_classroom_step
    job_id = SchoolCalendarSetterByStepWorker.perform_in(10.seconds, current_entity.id, params[:synchronize], current_user.id)

    WorkerState.create(
      user: current_user,
      job_id: job_id,
      kind: 'SchoolCalendarSetterByStepWorker',
      status: ApiSynchronizationStatus::STARTED
    )
  end

  def filtering_params(params)
    params = {} unless params
    params.slice(:by_year,
                 :by_unity_id)
  end

  def resource
    @school_calendar ||= case params[:action]
    when 'new', 'create'
      SchoolCalendar.new
    when 'edit', 'update', 'destroy'
      SchoolCalendar.find(params[:id])
    end
  end

  def resource_params
    params.require(:school_calendar).permit(:year,
                                            :number_of_classes,
                                            steps_attributes: [:id,
                                                               :start_at,
                                                               :end_at,
                                                               :start_date_for_posting,
                                                               :end_date_for_posting,
                                                               :_destroy],
                                            classrooms_attributes: [:id,
                                                                    :classroom,
                                                                    :_destroy,
                                            classroom_steps_attributes: [:id,
                                                               :start_at,
                                                               :end_at,
                                                               :start_date_for_posting,
                                                               :end_date_for_posting]])
  end
end
