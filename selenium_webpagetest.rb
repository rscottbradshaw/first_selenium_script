require 'selenium-webdriver'
require 'crack'
require 'open-uri'
require 'nokogiri'
require 'gmail'

# Config variables
@xml_urls = []
@email_body = ""
@email_data = ""
@unit = 1000 # time in milliseconds
@unit_bytes = 1024
@base_Path = "/Users/scottbradshaw/code/first_selenium_script/"
# Variable for the path
@waitForXMLResult = 10
# End config variables#####

# Reading in the list of URLS
@urls = []
inFile = File.open("#{@base_Path}selenium_webpagetest_urls.txt", "r")

while (line = inFile.gets)
  @urls << line.to_s.chomp
end

for i in (0..@urls.length-1)
  puts "Testing these URLS [#{i+1}] : " + @urls[i].to_s.chomp #print put urls in array and trim \n
end

sleep 1.5

inFile.close
@driver = Selenium::WebDriver.for :firefox

for i in (0..@urls.length-1)
  print "#{@urls[i]}|"
  begin
    @driver.navigate.to "http://www.webpagetest.org/"
    sleep 1
  end
  sleep 1

  # Now clearing the urls input field

  if @driver.find_element(:css, '#url').displayed? then
    element = @driver.find_element(:css, '#url')
  else
    puts "Cannot find #url element!"
  end
  puts "attempting to clear URL input!"
  element.clear()
  puts "Cleared URL input!"
  element.send_keys "#{@urls[i]}"

  puts 'looking for submit button'
  @driver.find_element(:css, '.start_test').click
  sleep 2
  print "result url: " + @driver.current_url + "\n"
  @resulting_url = @driver.current_url
  @xml_url = @driver.current_url.gsub("result", "xmlResult").to_s.chomp
  @xml_urls << @xml_url

  puts "This URL: #{@urls[i]}"
  puts "This URLs xml_url: #{@xml_url}"
  puts "Web page tests are now starting"
  puts "#{i+1} of #{@urls.length} input urls started"

end # end urls loop
@driver.quit

for i in (0..@xml_urls.length-1)
  puts @xml_urls[i]
end # Prints out the xml urls

for i in (0..@xml_urls.length-1)
  @xml_url = @xml_urls[i]
  uri = URI.parse(URI.encode(@xml_url))
  response = Net::HTTP.get(URI(uri)) # Send web page test request
  parsed_res = Crack::XML.parse(response) # Parse web page test response
  status = parsed_res["response"]["statusCode"] # Assigns the HTTP code to status
  puts "status: " + status

  until (status.to_i == 200) do
    puts "Status Code on getting xmlResult is: #{status.to_s}"
    puts "Sleeping #{@waitForXMLResult.to_s}..."
    sleep @waitForXMLResult.to_i # Waiting for 10 seconds

    uri = URI.parse(URI.encode(@xml_url))
    response = Net::HTTP.get(URI(uri)) # Sending the web page test request again
    parsed_res = Crack::XML.parse(response) # Parse web page test response
    status = parsed_res["response"]["statusCode"] # Assigns the HTTP code to status
  end

  puts "Test #{i+1} for #{@xml_url} finished with Status Code: #{status}...\n"

  begin
    # Convert the results to times that make more sense like seconds and Kilobytes
    # This is the original test URL reading it from the xmlResult
    @test_url = parsed_res["response"]["data"]["testUrl"]
    @completed_time = parsed_res["response"]["data"]["completed"]
    @median_loadtime = (parsed_res["response"]["data"]["median"]["firstView"]["loadTime"].to_f/@unit).to_s
    @median_TTFB = (parsed_res["response"]["data"]["median"]["firstView"]["TTFB"].to_f/@unit).to_s
    @median_start_render = (parsed_res["response"]["data"]["median"]["firstView"]["render"].to_f/@unit).to_s
    @median_speed_index = parsed_res["response"]["data"]["median"]["firstView"]["SpeedIndex"]
    @median_dc_time = (parsed_res["response"]["data"]["median"]["firstView"]["docTime"].to_f/@unit).to_s
    @median_dc_requests = parsed_res["response"]["data"]["median"]["firstView"]["requestsDoc"]
    @median_dc_bytes_in = (parsed_res["response"]["data"]["median"]["firstView"]["bytesInDoc"].to_f/@unit_bytes).round.to_s
    @median_fl_time = (parsed_res["response"]["data"]["median"]["firstView"]["fullyLoaded"].to_f/@unit).to_s
    @median_fl_requests = parsed_res["response"]["data"]["median"]["firstView"]["requests"]
    @median_fl_bytes_in = (parsed_res["response"]["data"]["median"]["firstView"]["bytesIn"].to_f/@unit_bytes).round.to_s

    @resultURL = @xml_url.gsub("xmlResult", "result")

    # Concatenate all fields into bigString
    @outputStr = "Requested URL:#{@test_url}|Result URL:#{@resultURL}|Result XML URL:#{@xml_url}|Completed Time:#{@completed_time}|Load Time:#{@median_loadtime}|TTFB:#{@median_TTFB}|Start Render:#{@median_start_render}|Speed Index:#{@median_speed_index}|DC Time:#{@median_dc_time}|DC Requests:#{@median_dc_requests}|DC Bytes:#{@median_dc_bytes_in}|FL Time:#{@median_fl_time}|FL Requests:#{@median_fl_requests}|FL Bytes:#{@median_fl_bytes_in}|\n"

    puts @outputStr
      # Now send the results in an email to let me know it's finished running
  rescue Exception => e
    puts "\n**Got an Exception: " + e.to_s
  end # end begin rescue loop
end # End loop for requesting xml from web page test

puts "Sending email notification!"

@email_outputStr = File.open("#{@base_Path}selenium_results_data_for_email.txt", "w")
@email_outputStr.print("#{@outputStr}")
@email_outputStr.close

begin
  gmail = Gmail.connect('EMAIL_USERNAME', 'EMAIL_PASSWORD')
  email = gmail.compose do
    to 'EMAIL'
    subject "Selenium Web Page Test Complete"
    body File.read('selenium_results_data_for_email.txt')
  end
  email.deliver!
  # gmail.logout
rescue Exception=>e
  puts "\n**Got an Exception trying to send email: " + e.to_s
end # end begin email rescue loop
puts "Email sent!"
