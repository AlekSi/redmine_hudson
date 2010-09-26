module RexmlHelper
  def get_element_value(element, name)
    value = element.try(:get_text, name).try(:value)
    value.present? ? value : ""
  end
end
