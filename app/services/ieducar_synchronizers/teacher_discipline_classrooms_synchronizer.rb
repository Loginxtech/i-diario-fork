class TeacherDisciplineClassroomsSynchronizer < BaseSynchronizer
  def synchronize!
    update_teacher_discipline_classrooms(
      HashDecorator.new(
        api.fetch(
            ano: year,
            escola: unity_api_code
        )['vinculos']
      )
    )
  end

  private

  def api_class
    IeducarApi::TeacherDisciplineClassrooms
  end

  def update_teacher_discipline_classrooms(teacher_discipline_classrooms)
    ActiveRecord::Base.transaction do
      teacher_discipline_classrooms.each do |teacher_discipline_classroom_record|
        existing_discipline_api_codes = []
        created_linked_teachers = []

        (teacher_discipline_classroom_record.disciplinas || []).each do |discipline_by_score_type|
          discipline_api_code, score_type = discipline_by_score_type.split
          existing_discipline_api_codes << discipline_api_code

          created_linked_teachers << create_or_update_teacher_discipline_classrooms(
            teacher_discipline_classroom_record,
            discipline_api_code,
            score_type
          )
        end

        create_or_destroy_teacher_disciplines_classrooms(created_linked_teachers)

        discard_inexisting_teacher_discipline_classrooms(
          teacher_discipline_classrooms_to_discard(
            teacher_discipline_classroom_record,
            existing_discipline_api_codes
          )
        )

        create_empty_conceptual_exam_value(teacher_discipline_classroom_record) unless teacher_discipline_classroom_record.deleted_at.present?
      end
    end
  end

  def create_or_update_teacher_discipline_classrooms(
    teacher_discipline_classroom_record,
    discipline_api_code,
    score_type
  )
    teacher_id = teacher(teacher_discipline_classroom_record.servidor_id).try(:id)

    return if teacher_id.blank?

    classroom_id = classroom(teacher_discipline_classroom_record.turma_id).try(:id)

    return if classroom_id.blank?

    discipline_id = discipline(discipline_api_code).try(:id)

    return if discipline_id.blank?

    teacher_discipline_classrooms = TeacherDisciplineClassroom.unscoped.where(
      api_code: teacher_discipline_classroom_record.id,
      year: year,
      discipline_id: discipline_id,
      discipline_api_code: discipline_api_code
    )

    teacher_discipline_classroom =
      if teacher_discipline_classrooms.size == 1
        teacher_discipline_classrooms.first
      elsif teacher_discipline_classrooms.size > 1
        teacher_discipline_classrooms.find_by(discarded_at: nil)
      end

    teacher_discipline_classroom ||= TeacherDisciplineClassroom.new(
      api_code: teacher_discipline_classroom_record.id,
      year: year,
      teacher_id: teacher_id,
      teacher_api_code: teacher_discipline_classroom_record.servidor_id,
      discipline_id: discipline_id,
      discipline_api_code: discipline_api_code
    )

    teacher_discipline_classroom.classroom_id = classroom_id
    teacher_discipline_classroom.classroom_api_code = teacher_discipline_classroom_record.turma_id
    teacher_discipline_classroom.allow_absence_by_discipline =
      teacher_discipline_classroom_record.permite_lancar_faltas_componente
    teacher_discipline_classroom.changed_at = teacher_discipline_classroom_record.updated_at
    teacher_discipline_classroom.period = teacher_discipline_classroom_record.turno_id
    teacher_discipline_classroom.score_type = score_type
    teacher_discipline_classroom.active = true if teacher_discipline_classroom.active.nil?
    teacher_discipline_classroom.save! if teacher_discipline_classroom.changed?

    if teacher_discipline_classroom.new_record?
      cache_key = "last_teacher_discipline_classroom-#{classroom_id}-#{teacher_id}"
      Rails.cache.delete(cache_key)
    end

    teacher_discipline_classroom.discard_or_undiscard(false)

    teacher_discipline_classroom
  end

  def discard_inexisting_teacher_discipline_classrooms(teacher_discipline_classrooms_to_discard)
    teacher_discipline_classrooms_to_discard.each do |teacher_discipline_classroom|
      teacher_discipline_classroom.discard_or_undiscard(true)
    end
  end

  def teacher_discipline_classrooms_to_discard(teacher_discipline_classroom_record, existing_discipline_api_codes)
    teacher_discipline_classrooms = TeacherDisciplineClassroom.unscoped.where(
      api_code: teacher_discipline_classroom_record.id,
      year: year
    )

    existing_disciplines_ids = Discipline.where(api_code: existing_discipline_api_codes)
                                         .pluck(:id)

    return teacher_discipline_classrooms if teacher_discipline_classroom_record.deleted_at.present?

    teacher_discipline_classrooms.where.not(discipline_id: existing_disciplines_ids)
  end

  def create_empty_conceptual_exam_value(teacher_discipline_classroom_record)
    classroom = classroom(teacher_discipline_classroom_record.turma_id)
    classroom_id = classroom.try(:id)
    teacher_id = teacher(teacher_discipline_classroom_record.servidor_id).try(:id)
    hash_api_codes = teacher_discipline_classroom_record.disciplinas_serie.to_h

    grade_in_disciplines = {}

    return if hash_api_codes.blank?

    hash_api_codes.each do |grade, disciplines|
      next if grade.blank?

      grade_id = Grade.find_by(api_code: grade).try(:id)
      discipline_ids = Discipline.where(api_code: disciplines).pluck(:id)

      grade_in_disciplines[grade_id] ||= []
      grade_in_disciplines[grade_id] = discipline_ids
    end

    return if teacher_id.nil?
    return if classroom_id.nil?
    return if classroom.discarded?
    return if grade_in_disciplines.blank?

    CreateEmptyConceptualExamValueWorker.perform_in(
      1.second,
      entity_id,
      classroom_id,
      teacher_id,
      grade_in_disciplines
    )
  end

  def create_or_destroy_teacher_disciplines_classrooms(linked_teachers)
    teacher_discipline_classrooms_ids = linked_teachers.map(&:id)

    TeacherDisciplineClassroom.includes(discipline: { knowledge_area: :disciplines })
                              .where(id: teacher_discipline_classrooms_ids)
                              .where(knowledge_areas: { group_descriptors: true })
                              .each do |teacher_discipline_classroom|
      fake_discipline = Discipline.unscoped.find_by(
        knowledge_area_id: teacher_discipline_classroom.knowledge_area.id,
        grouper: true
      )

      return if fake_discipline.nil?

      TeacherDisciplineClassroom.find_or_initialize_by(
        api_code: "grouper:#{fake_discipline.id}",
        year: year,
        teacher_id: teacher_discipline_classroom.teacher_id,
        teacher_api_code: teacher_discipline_classroom.teacher_api_code,
        discipline_id: fake_discipline.id,
        discipline_api_code: "grouper:#{fake_discipline.id}",
        classroom_id: teacher_discipline_classroom.classroom_id,
        classroom_api_code: "grouper:#{fake_discipline.id}"
      ).save!
    end
  end
end