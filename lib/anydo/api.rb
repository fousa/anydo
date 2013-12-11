require "faraday"
require "json"
require "base64"
require 'highline/import'

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
            j_username: "jelle.vandebeeck@gmail.com",
            j_password: "Pablo0325",
            _spring_security_remember_me: "on"
        }
        result = connection.post do |request|
            request.url "/j_spring_security_check"
            request.body = params
        end
        cookie = reformat_cookies result.headers["set-cookie"]
        raise "INVALID USERNAME/PASSWORD" unless cookie

        yield cookie
    end

    def create(title)
        authenticate do |cookie|
            params = [{
                id: generate_global_id,
                priority: "Normal",
                status: "UNCHECKED",
                title: title
            }]
            result = connection.post do |request|
                request.url "/me/tasks"
                request.headers['Cookie'] = cookie
                request.headers['Content-Type'] = "application/json"
                request.body = params.to_json
            end
            raise "CREATING TODO FAILED" unless result.status == 200

            puts "◻︎ '#{title}' created"
        end
    end

    def check(task)
        task[:status] = "CHECKED"
        authenticate do |cookie|
            result = connection.put do |request|
                request.url "/me/tasks/#{task["id"]}"
                request.headers['Cookie'] = cookie
                request.headers['Content-Type'] = "application/json"
                request.body = task.to_json
            end
            raise "FINISHING TODO FAILED" unless result.status == 200

            puts "☑︎ '#{title}'"
        end
    end

    def list(all=false, finish=false)
        authenticate do |cookie|
            result = connection.get do |request|
                request.url "/me/tasks?responseType=flat&includeDeleted=0&includeDone=0"
                request.headers['Cookie'] = cookie
                request.headers['Content-Type'] = "application/json"
            end
            raise "FETCHING TODOS FAILES" unless result.status == 200

            tasks = JSON.parse(result.body)
            tasks = tasks.select { |t| t["status"] == "UNCHECKED" } unless all
            tasks = tasks.select { |t| today?(parse_time(t["dueDate"])) }
            tasks = tasks.sort_by { |t| t["dueDate"].to_i }

            if finish
                choose do |menu|
                    menu.prompt = "\nSelect the todo you just completed: "
                    tasks.each do |t|
                        menu.choice t["title"] { check(t) }
                    end
                end
            else
                if all
                    puts "All your todos"
                else
                    puts "Your todos for today"
                end
                tasks.each { |t| puts "| " + print_task(t) }
            end
        end
    end

    private

    def print_task(t)
        text = t["title"]
        if t["dueDate"] != 0 && time = parse_time(t["dueDate"])
            text += " (#{time.hour}:#{"%02i" % time.min})" 
        end

        checkbox = t["status"] == "UNCHECKED" ? "◻︎" : "☑︎"

        "#{checkbox} #{text}"
    end

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

    def generate_global_id
        random_string = (0...16).map{ ('a'..'z').to_a[rand(26)] }.join
        Base64.encode64(random_string).gsub("+", "-").gsub("/", "_").gsub("\n", "")
    end
end

api = Api.new

# todos for today
#api.list

# all todos
api.list(true)

#api.today
#api.finish
#api.create("piepken")
