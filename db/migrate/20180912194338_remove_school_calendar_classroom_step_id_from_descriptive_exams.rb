class RemoveSchoolCalendarClassroomStepIdFromDescriptiveExams < ActiveRecord::Migration[4.2]
  def change
    remove_column :descriptive_exams, :school_calendar_classroom_step_id, :integer
  end
end
