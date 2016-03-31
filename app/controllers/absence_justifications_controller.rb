class AbsenceJustificationsController < ApplicationController
  has_scope :page, default: 1
  has_scope :per, default: 10

  def index
    @classrooms = Classroom.by_unity_and_teacher(current_user_unity.id, current_teacher.id)
    @absence_justifications = apply_scopes(AbsenceJustification.by_author(current_user.id).where(unity_id: current_user_unity)
                                                                .filter(filtering_params(params[:search]))
                                                                .includes(:student).ordered)

    authorize @absence_justifications
  end

  def new
    @absence_justification = AbsenceJustification.new.localized
    @absence_justification.absence_date = Time.zone.today
    @absence_justification.author = current_user
    @absence_justification.unity = current_user_unity
    @classrooms = Classroom.by_unity_and_teacher(current_user_unity.id, current_teacher.id)
    @teacher_id = current_teacher.id

    authorize @absence_justification
  end

  def create
    @absence_justification = AbsenceJustification.new(resource_params)
    @absence_justification.author = current_user
    @absence_justification.unity = current_user_unity

    authorize @absence_justification

    if @absence_justification.save
      respond_with @absence_justification, location: absence_justifications_path
    else
      @classrooms = Classroom.by_unity_and_teacher(current_user_unity, current_teacher.id)
      render :new
    end
  end

  def edit
    @absence_justification = AbsenceJustification.find(params[:id]).localized
    @classrooms = Classroom.by_teacher_id(current_teacher.id)

    validate_current_user

    authorize @absence_justification
  end

  def update
    @absence_justification = AbsenceJustification.find(params[:id])
    @absence_justification.assign_attributes resource_params

    authorize @absence_justification

    if @absence_justification.save
      respond_with @absence_justification, location: absence_justifications_path
    else
      render :edit
    end
  end

  def destroy
    @absence_justification = AbsenceJustification.find(params[:id])

    @absence_justification.destroy

    respond_with @absence_justification, location: absence_justifications_path
  end

  def history
    @absence_justification = AbsenceJustification.find(params[:id])

    authorize @absence_justification

    respond_with @absence_justification
  end

  protected

  def resource_params
    params.require(:absence_justification).permit(
      :student_id, :absence_date, :justification, :absence_date_end,
      :unity_id, :classroom_id
    )
  end

  private

  def validate_current_user
    unless @absence_justification.author_id.eql?(current_user.id)
      flash[:alert] = t('.current_user_not_allowed')
      redirect_to root_path
    end
  end

  def filtering_params(params)
    if params
      params.slice(:by_classroom, :by_student, :by_absence_date, :by_absence_date_end)
    else
      {}
    end
  end

  protected

  def fetch_students
    begin
      api = IeducarApi::Students.new(configuration.to_api)
      result = api.fetch_for_daily(
        {
          classroom_api_code: @absence_justification.classroom.api_code,
          discipline_api_code: @absence_justification.discipline.try(:api_code),
          date: Time.zone.today
        }
      )

      @api_students = result['alunos'].uniq
    rescue IeducarApi::Base::ApiError => e
      flash[:alert] = e.message
      @api_students = []
      redirect_to new_daily_frequency_path
    end
  end

  def configuration
    @configuration ||= IeducarApiConfiguration.current
  end
end
