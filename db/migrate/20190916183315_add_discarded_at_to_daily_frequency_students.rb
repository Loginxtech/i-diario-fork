class AddDiscardedAtToDailyFrequencyStudents < ActiveRecord::Migration
  def change
    add_column :daily_frequency_students, :discarded_at, :datetime

    remove_index :daily_frequency_students, name: 'daily_frequency_students_daily_frequency_id_student_id_idx'

    add_index(
      :daily_frequency_students,
      [:daily_frequency_id, :student_id, :discarded_at],
      unique: true,
      name: 'daily_frequency_students_daily_frequency_id_student_id_idx'
    )
  end
end
