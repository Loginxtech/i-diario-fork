class StudentUnificationService
  KEEP_ASSOCIATIONS = [
    :audits,
    :deficiencies,
    :student_enrollments,
    :absence_justifications,
    :student_unifications,
    :student_unification_students
  ].freeze

  def initialize(main_student, secondary_students)
    @main_student = main_student
    @secondary_students = secondary_students
  end

  def run!
    @secondary_students.each do |secondary_student|
      Student.reflect_on_all_associations(:has_many).each do |association|
        next if KEEP_ASSOCIATIONS.include?(association.name)

        secondary_student.send(association.name).each do |record|
          begin
            unify(record)
          rescue ActiveRecord::RecordNotUnique
            discard(record)
            unify(record)
          end
        end
      end
    end
  end

  def unify(record)
    record.student_id = @main_student.id
    record.save!(validate: false)
  end

  def discard(record)
    record.update_column(:discarded_at, Time.current)
  end
end
