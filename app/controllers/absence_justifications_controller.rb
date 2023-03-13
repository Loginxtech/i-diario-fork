class AbsenceJustificationsController < ApplicationController
  before_action :require_current_teacher
  before_action :require_current_classroom
  before_action :is_frequency_by_discipline?, only: [:new, :edit, :create, :update]

  has_scope :page, default: 1
  has_scope :per, default: 10

  before_action :require_allow_to_modify_prev_years, only: [:create, :update, :destroy]

  # TODO: release-absence-justification
  # - [ ] Remover vínculo com professor
  # - [ ] Remover vínculo com disciplina
  # - [ ] Não permitir edição de justificativas de anos anterioes à 2023
  # - [ ] Permitir lançar em lote, editar individual

  def index
    @classrooms = Classroom.where(id: current_user_classroom)

    author_type = (params[:search] || []).delete(:by_author)

    @absence_justifications = apply_scopes(AbsenceJustification.includes(:teacher)
                                                               .includes(:classroom)
                                                               .includes(:unity)
                                                               .joins(:absence_justifications_students)
                                                               .by_unity(current_unity)
                                                               .by_classroom(current_user_classroom)
                                                               .by_school_calendar(current_school_calendar)
                                                               .filter(filtering_params(params[:search]))
                                                               .includes(:students).uniq.ordered)

    if author_type.present?
      user_id = UserDiscriminatorService.new(current_user, current_user.current_role_is_admin_or_employee?).user_id

      @absence_justifications = @absence_justifications.by_author(author_type, user_id)
      params[:search][:by_author] = author_type
    end

    authorize @absence_justifications
  end

  def new
    @absence_justification = AbsenceJustification.new.localized
    @absence_justification.absence_date = Time.zone.today
    @absence_justification.teacher = current_teacher
    @absence_justification.unity = current_unity
    @absence_justification.school_calendar = current_school_calendar
    fetch_collections
    fetch_students

    authorize @absence_justification
  end

  def create
    class_numbers = params[:absence_justification][:class_number].split(',')

    if class_numbers.empty?
      class_numbers = [nil]
    end

    valid = class_numbers.map do |class_number|
      @absence_justification = AbsenceJustification.new(resource_params)
      @absence_justification.class_number = class_number
      @absence_justification.teacher = current_teacher
      @absence_justification.user = current_user
      @absence_justification.unity = current_unity
      @absence_justification.school_calendar = current_school_calendar

      authorize @absence_justification

      @absence_justification.save
    end

    valid = valid.reject { |is_valid| is_valid }.empty?

    if valid
      respond_with @absence_justification, location: absence_justifications_path
    else
      clear_invalid_dates
      fetch_collections
      fetch_students
      render :new
    end
  end

  def edit
    @absence_justification = AbsenceJustification.find(params[:id]).localized
    @absence_justification.unity = current_unity
    fetch_collections
    fetch_students

    authorize @absence_justification
  end

  def update
    @absence_justification = AbsenceJustification.find(params[:id])
    @absence_justification.assign_attributes resource_params_edit
    @absence_justification.current_user = current_user
    @absence_justification.school_calendar = current_school_calendar if @absence_justification.persisted? && @absence_justification.school_calendar.blank?
    fetch_collections

    authorize @absence_justification

    if @absence_justification.save
      respond_with @absence_justification, location: absence_justifications_path
    else
      clear_invalid_dates
      render :edit
      fetch_collections
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
    parameters = params.require(:absence_justification).permit(
      :student_ids,
      :absence_date,
      :justification,
      :absence_date_end,
      :unity_id,
      :classroom_id,
      absence_justification_attachments_attributes: [
        :id,
        :attachment,
        :_destroy
      ]
    )

    parameters[:student_ids] = parameters[:student_ids].split(',')

    parameters
  end

  def resource_params_edit
    params.require(:absence_justification).permit(
      :justification,
      absence_justification_attachments_attributes: [
        :id,
        :attachment,
        :_destroy
      ]
    )
  end

  private

  def filtering_params(params)
    if params
      params.slice(:by_classroom, :by_student, :by_date, :by_author)
    else
      {}
    end
  end

  protected

  def fetch_students
    # TODO: remover filtro por disciplina, não faz mais sentido
    student_enrollments = StudentEnrollmentsList.new(
      classroom: current_user_classroom,
      discipline: fetch_current_discipline,
      search_type: :by_date,
      date: Date.current
    ).student_enrollments

    student_ids = student_enrollments.collect(&:student_id)
    @students = Student.where(id: student_ids)
  end

  def fetch_collections
    @unities = Unity.by_teacher(current_teacher_id).ordered
    @classrooms = Classroom.by_unity_and_teacher(current_unity, current_teacher_id)
  end

  def configuration
    @configuration ||= IeducarApiConfiguration.current
  end

  def fetch_current_discipline
    frequency_type_definer = FrequencyTypeDefiner.new(current_user_classroom, current_teacher)
    frequency_type_definer.define!

    if frequency_type_definer.frequency_type == FrequencyTypes::BY_DISCIPLINE
      current_user_discipline
    else
      nil
    end
  end

  def is_frequency_by_discipline?
    if @is_frequency_by_discipline.nil?
      frequency_type_definer = FrequencyTypeDefiner.new(current_user_classroom, current_teacher)
      frequency_type_definer.define!

      @is_frequency_by_discipline = frequency_type_definer.frequency_type == FrequencyTypes::BY_DISCIPLINE
    end

    @is_frequency_by_discipline
  end

  def clear_invalid_dates
    begin
      resource_params[:absence_date].to_date
    rescue ArgumentError
      @absence_justification.absence_date = ''
    end

    begin
      resource_params[:absence_date_end].to_date
    rescue ArgumentError
      @absence_justification.absence_date_end = ''
    end
  end
end
