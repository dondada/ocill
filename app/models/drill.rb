class Drill < ActiveRecord::Base
  attr_accessible :instructions, :lesson_id, :position, :prompt, :title, :exercises_attributes, :type, :headers_attributes

  belongs_to :lesson
  alias :parent :lesson
  has_many :exercises, :dependent => :destroy, :autosave => true
  alias :children :exercises
  has_many :exercise_items, :through => :exercises, :autosave => true
  has_many :headers, :dependent => :destroy, :autosave => true 
  accepts_nested_attributes_for :exercises, allow_destroy: true
  accepts_nested_attributes_for :headers, allow_destroy: true
 
  before_save :set_default_title

  def course
    self.lesson.course unless self.lesson.nil?
  end
  
  def rows
    self.exercises.size
  end

private
  def set_default_title 
    self.title = "Default Title" if self.title.blank?
  end
end
