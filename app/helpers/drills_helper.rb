module DrillsHelper
  def show_headers(drill)
    html = "<thead><tr>"
    html += '<th scope="col">' + ( drill.title || "&nbsp;" ) + '</th>'
    drill.headers.each do |h|
      html += '<th scope="col">'
      html += ( h.title || "&nbsp;" ) + '</th>'
    end
    html += '</tr></thead>'
  end

  def before_exercise_wrapper(drill, width="200" )
    direction = (drill.rtl == "1") ? '"rtl"' : '"ltr"'
    case drill.type
    when "GridDrill"
      html = '<table dir=#{direction} class ="table" width="' + width + '" border="1" summary="A set of exercises for this'
      html += @drill.type.to_s.titleize + '">'
      html += show_headers(@drill).to_s
    when "FillDrill"
      html = "<ol dir=#{direction}>"
    else
      html = "&nbsp;"
    end
  end

  def after_exercise_wrapper(drill)
    case drill.type
    when "GridDrill"
      html = '</table>'
    when "FillDrill"
      html = '</ol>'
    else
      html = "&nbsp;"
    end
  end
end
