Then(/^the resource list should have the new resource$/) do
  expect(@result.map{|r| r['id']}).to include(@current_resource.id)
end

Then(/^the resource list should not have the new resource$/) do
  expect(@result.map{|r| r['id']}).to_not include(@current_resource.id)
end

Then(/^the binary result is "([^"]*)"$/) do |value|
  expect(@result).to be
  expect(@result.headers[:content_type]).to include("application/octet-stream")
  expect(@result).to eq(value)
end

Then(/^the binary result is preserved$/) do
  expect(@result).to be
  expect(@result.headers[:content_type]).to include("application/octet-stream")
  expect(@result).to eq(@value)
end