class StudentsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:search_api]

  def index
    if params[:classroom_id]
      date = params[:date].present? ? params[:date] : Date.today
      classroom = Classroom.find(params[:classroom_id])
      step_number = SchoolCalendarClassroomStep.find(params[:school_calendar_classroom_step_id]).to_number if params[:school_calendar_classroom_step_id].present?
      step_number = SchoolCalendarStep.find(params[:school_calendar_step_id]).to_number unless step_number

      @students = StudentsFetcher.new(
        classroom,
        Discipline.find(params[:discipline_id]),
        date.to_date.to_s,
        params[:start_date],
        params[:score_type] || StudentEnrollmentScoreTypeFilters::BOTH,
        step_number
      )
      .fetch

      render json: @students
    else
      @students = apply_scopes(Student).ordered

      respond_with @students
    end
  end

  def search_api
    begin
      api = IeducarApi::Students.new(configuration.to_api)
      result = api.fetch_by_cpf(params[:document], params[:student_code])

      render json: result["alunos"].to_json
    rescue IeducarApi::Base::ApiError => e
      render json: e.message, status: "404"
    end
  end

  def in_recovery
    @students = StudentsInRecoveryFetcher.new(
        configuration,
        params[:classroom_id],
        params[:discipline_id],
        params[:school_calendar_step_id],
        params[:date].to_date.to_s
      )
      .fetch

    render(
      json: @students,
      each_serializer: StudentInRecoverySerializer,
      discipline: discipline,
      classroom: classroom,
      school_calendar_step: school_step,
      number_of_decimal_places: school_step.test_setting.number_of_decimal_places
    )
  end

  def in_recovery_classroom_steps
    @students = StudentsInRecoveryByClassroomStepFetcher.new(
        configuration,
        params[:classroom_id],
        params[:discipline_id],
        params[:school_calendar_classroom_step_id],
        params[:date].to_date.to_s
      )
      .fetch

    render(
      json: @students,
      each_serializer: StudentInRecoveryClassroomStepSerializer,
      discipline: discipline,
      classroom: classroom,
      school_calendar_classroom_step: classroom_step,
      number_of_decimal_places: classroom_step.test_setting.number_of_decimal_places
    )
  end

  def in_final_recovery
    @students = StudentsInFinalRecoveryFetcher.new(configuration)
      .fetch(
        params[:classroom_id],
        params[:discipline_id]
      )

    render(
      json: @students,
      each_serializer: StudentInFinalRecoverySerializer
    )
  end

  private

  def configuration
    IeducarApiConfiguration.current
  end

  def classroom
    Classroom.find(params[:classroom_id])
  end

  def school_step
    SchoolCalendarStep.find(params[:school_calendar_step_id])
  end

  def classroom_step
    SchoolCalendarClassroomStep.find(params[:school_calendar_classroom_step_id])
  end

  def discipline
    Discipline.find(params[:discipline_id])
  end
end
