class ParameterError < StandardError
  def initialize(msg="Parameter error")
    super
  end
end

class NotFoundError < StandardError
  def initialize(msg="Record not found")
    super
  end
end
