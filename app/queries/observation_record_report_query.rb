class ObservationRecordReportQuery
  def initialize(unity_id, teacher_id, classroom_id, discipline_id, start_at, end_at, current_user_id)
    @unity_id = unity_id
    @teacher_id = teacher_id
    @classroom_id = classroom_id
    @discipline_id = discipline_id
    @start_at = start_at.to_date
    @end_at = end_at.to_date
    @current_user_id = current_user_id
  end

  def observation_diary_records
    if @classroom_id.eql?('all')
      user = User.find(current_user_id)
      classrooms_id = if user.teacher?
                        Classroom.by_unity_and_teacher(unity_id, user.id).pluck(:id)
                      else
                        Classroom.by_unity(unity_id).pluck(:id)
                      end
      relation = ObservationDiaryRecord.includes(notes: :students)
                                       .by_classroom(classrooms_id)
                                       .where(date: start_at..end_at)
                                       .order(:date)
    else
      relation = ObservationDiaryRecord.includes(notes: :students)
                                       .by_teacher(teacher_id)
                                       .by_classroom(classroom_id)
                                       .where(date: start_at..end_at)
                                       .order(:date)

      relation = relation.by_discipline(discipline_id) if discipline_id.present?
    end

    relation
  end

  private

  attr_accessor :unity_id, :teacher_id, :classroom_id, :discipline_id, :start_at, :end_at, :current_user_id
end
