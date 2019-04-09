class String
  def estimate 
    if include?("+")
      delete(",").to_f
    else
      delete(",").prepend("-").to_f
    end
  end
end