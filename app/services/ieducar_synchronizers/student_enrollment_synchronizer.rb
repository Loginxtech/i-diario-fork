class StudentEnrollmentSynchronizer < BaseSynchronizer
  def synchronize!
    update_student_enrollments(
      HashDecorator.new(
        api.fetch(
          ano: years.first,
          escola: unity_api_code
        )['matriculas']
      )
    )
  end

  def self.synchronize_in_batch!(params)
    params[:use_unity_api_code] = true

    super do |unity_api_code|
      params[:years].each do |year|
        new(
          synchronization: params[:synchronization],
          worker_batch: params[:worker_batch],
          years: [year],
          unity_api_code: unity_api_code,
          entity_id: params[:entity_id]
        ).synchronize!
      end
    end
  end

  private

  def api_class
    IeducarApi::StudentEnrollments
  end

  def update_student_enrollments(student_enrollments)
    return if student_enrollments.blank?

    student_enrollments.each do |student_enrollment_record|
      student_id = student(student_enrollment_record.aluno_id).try(:id)

      next if student_id.blank?

      StudentEnrollment.with_discarded.find_or_initialize_by(
        api_code: student_enrollment_record.matricula_id
      ).tap do |student_enrollment|
        student_enrollment.status = student_enrollment_record.situacao
        student_enrollment.student_id = student_id
        student_enrollment.student_code = student_enrollment_record.aluno_id
        student_enrollment.changed_at = student_enrollment_record.updated_at
        student_enrollment.active = student_enrollment_record.ativo
        student_enrollment.save! if student_enrollment.changed?

        student_enrollment.discard_or_undiscard(student_enrollment_record.deleted_at.present?)
      end
    end
  end
end
