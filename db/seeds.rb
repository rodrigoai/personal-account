%w[Housing Food Transport Health Shopping Subscriptions Salary Transfers].each do |name|
  kind = name == "Salary" ? :income : :outcome
  category = Category.find_or_initialize_by(name: name, parent_id: nil)
  category.update!(kind: kind)
end

Category.not_identified!
