class RecoveryDiaryRecord < ActiveRecord::Base
  include Audit

  acts_as_copy_target

  audited

  belongs_to :unity
  belongs_to :classroom, -> { includes(:exam_rule) }
  belongs_to :discipline

  has_many :students, -> { includes(:student).ordered },
    class_name: 'RecoveryDiaryRecordStudent',
    dependent: :destroy

  accepts_nested_attributes_for :students, allow_destroy: true

  has_one :school_term_recovery_diary_record
  has_one :final_recovery_diary_record
  has_one :avaliation_recovery_diary_record

  validates :unity, presence: true
  validates :classroom, presence: true
  validates :discipline, presence: true
  validates :recorded_at, presence: true, school_calendar_day: true

  validate :at_least_one_assigned_student
  validate :recorded_at_must_be_less_than_or_equal_to_today

  before_validation :self_assign_to_students

  private

  def at_least_one_assigned_student
    errors.add(:students, :at_least_one_assigned_student) if students.reject(&:marked_for_destruction?).empty?
  end

  def recorded_at_must_be_less_than_or_equal_to_today
    return unless recorded_at

    if recorded_at > Time.zone.today
      errors.add(:recorded_at, :recorded_at_must_be_less_than_or_equal_to_today)
    end
  end

  def self_assign_to_students
    students.each { |student| student.recovery_diary_record = self }
  end

  def school_calendar
    CurrentSchoolCalendarFetcher.new(unity).fetch
  end
end
