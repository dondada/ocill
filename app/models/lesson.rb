class Lesson < ActiveRecord::Base
  attr_accessible :position, :title, :drills_attributes, :course_id
  belongs_to :course
  alias :parent :course
  has_many :drills, :autosave => true
  has_many :grid_drills, :autosave => true
  alias :children :drills
  has_many :exercises, :through => :drills
  has_many :exercise_items, :through => :drills

end