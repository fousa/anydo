require "faraday"
require "json"

class Api
    BASE_URL = "https://sm-prod.any.do"

    def connection
        Faraday.new(:url => BASE_URL) do |faraday|
            faraday.request  :url_encoded
            #faraday.response :logger
            faraday.adapter  Faraday.default_adapter
        end
    end

    def authenticate(&block)
        params = {
            j_username: "aaa",
            j_password: "bbb",
            _spring_security_remember_me: "on"
        }
        result = connection.post "/j_spring_security_check", params
        cookie = reformat_cookies result.headers["set-cookie"]
        raise "INVALID USERNAME/PASSWORD" unless cookie

        yield cookie
    end

    def list(tomorrow=false)
        authenticate do |cookie|
            result = connection.get do |request|
                request.url "/me/tasks?responseType=flat&includeDeleted=0&includeDone=0"
                request.headers['Cookie'] = cookie
                request.headers['Content-Type'] = "application/json"
            end
            if result.status == 401
            else
                tasks = JSON.parse(result.body)
                tasks = tasks.select { |t| t["status"] == "UNCHECKED" }
                tasks = tasks.select { |t| tomorrow ? tomorrows_task?(t) : todays_task?(t) }
                tasks = tasks.sort_by { |t| t["dueDate"].to_i }
                tasks.each_with_index do |t, i|
                    if t["dueDate"] != 0 && time = parse_time(t["dueDate"])
                        puts "#{i+1}| ◻︎ #{t["title"]} (#{time.hour}:#{"%02i" % time.min})"
                    else
                        puts "#{i+1}| ◻︎ #{t["title"]}"
                    end
                end
            end
        end
    end

    private

    def reformat_cookies cookies
        cookies = cookies.split(";").map { |c| c.split(",").map(&:strip) }.flatten

        authentication_cookie = cookies.detect { |c| c.start_with? "JSESSIONID" }
        remember_cookie = cookies.detect { |c| c.start_with? "SPRING_SECURITY_REMEMBER_ME_COOKIE" }

        if authentication_cookie && remember_cookie
            [authentication_cookie, remember_cookie].join(",")
        else
            nil
        end
    end

    def parse_time(task_date)
        if task_date == nil
            nil
        elsif task_date == 0
            Time.new
        else
            Time.at(task_date.to_i / 1000)
        end
    end

    def today?(time)
        return false if time.nil?

        today = Time.new
        today_start =  Time.new(today.year, today.month, today.day)
        today_end =  today_start + 86399

        (today_start..today_end).cover?(time)
    end

    def todays_task?(task)
        today?(parse_time(task["dueDate"]))
    end

    def tomorrow?(time)
        return false if time.nil?

        tomorrow = Time.new + 86400
        tomorrow_start =  Time.new(tomorrow.year, tomorrow.month, tomorrow.day)
        tomorrow_end =  tomorrow_start + 86399

        (tomorrow_start..tomorrow_end).cover?(time)
    end

    def tomorrows_task?(task)
        tomorrow?(parse_time(task["dueDate"]))
    end
end

api = Api.new
api.list(false)
