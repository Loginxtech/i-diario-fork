class DropUniqueTeacherDisciplineClassroomsIdx < ActiveRecord::Migration
  disable_ddl_transaction!

  def up
    execute %(
      DROP INDEX CONCURRENTLY IF EXISTS 'idx_unique_teacher_discipline_classrooms'
    )
  end

  def down
    add_index :teacher_discipline_classrooms, [:api_code, :teacher_id, :classroom_id, :discipline_id],
              name: 'idx_unique_teacher_discipline_classrooms', unique: true, algorithm: :concurrently
  end
end
