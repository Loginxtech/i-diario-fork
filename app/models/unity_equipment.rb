class UnityEquipment < ActiveRecord::Base
  acts_as_copy_target
  audited associated_with: :unity, except: :unity_id

  belongs_to :unity

  has_enumeration_for :biometric_type, with: BiometricTypes

  validates :unity, presence: true
  validates :code, presence: true, uniqueness: { scope: :unity_id }, numericality: { only_integer: true }
  validates :biometric_type, presence: true

  def to_s
    "#{code}"
  end
end