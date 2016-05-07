#!/usr/bin/env ruby

#####################################################################
### functions
#####################################################################

def connect_to_twitter
  if !File.exist?('credentials.rb')
    puts "🚫 You need to provide your twitter application connection keys in the credentials.rb file."
    puts "🤖 If you need to set up keys, you can do so here: https://apps.twitter.com"
    exit 1
  end
  require 'twitter'
  require_relative 'credentials.rb'
  twitter = Twitter::REST::Client.new do |config|
    config.consumer_key        = CONSUMER_KEY
    config.consumer_secret     = CONSUMER_SECRET
    config.access_token        = ACCESS_TOKEN
    config.access_token_secret = ACCESS_TOKEN_SECRET
  end
  return twitter
end

def get_user(twitter)
  authenticated_user = twitter.user.screen_name
  print "\n💁 Which user's follows do you want to query? (default: #{authenticated_user}) "
  user = gets.strip.downcase
  return user.empty? ? authenticated_user : user
end

def get_follows(twitter, user)
  puts "\n💩 Getting follows. This may take a while due to rate limiting..."
  friends = twitter.friends(user)
  begin
    friends_array = friends.to_a
  rescue Twitter::Error::Unauthorized
    print "🚫 you do not have access to this person's follows"
    return []
  rescue Twitter::Error::TooManyRequests => error
    puts "\t⏲ rate limit hit! pausing #{error.rate_limit.reset_in.to_s} seconds..."
    sleep error.rate_limit.reset_in + 1
    retry
  end
  friend_usernames = []
  friends_array.each do |f|
    friend_usernames << f.screen_name
  end
  return friend_usernames
end

# limiting this to 48 hours for now
def get_time(user)
  print "\n❓ Over how many minutes do you want to look at #{user}'s friends' tweets? "
  minutes = gets.to_i
  if minutes < 1 
    puts "🚫 Please enter a positive integer."
    return false
  elsif minutes > 2880
    puts "🚫 Please enter a time duration less than 48 hours (2880 minutes)"
    return false
  end
  return DateTime.now-minutes/1440.0
end

# the maximum number of tweets returned by the API are 200, but hopefully not 
# too many people are making that many tweets in under 48 hours...
def tweets_over_time(twitter, username, time)
  print "💬 "
  tweet_count = 0
  begin
    tweets = twitter.user_timeline(username, {count: 200, exclude_replies: true, include_rts: true, trim_user: true} )
    tweets.each do |tweet|
      if tweet.created_at.to_datetime >= time
        tweet_count += 1
      else
        print "🎉 "
        break
      end
    end
  rescue Twitter::Error::Unauthorized
    print "🚫 "
    return 0
  rescue Twitter::Error::TooManyRequests => error
    print "⏲ "
    sleep error.rate_limit.reset_in + 1
    retry
  end
  return tweet_count
end

#####################################################################
### execution
#####################################################################
 
twitter = connect_to_twitter

user = get_user(twitter)

time = false
while !time do
  time = get_time(user)
end
seconds = Time.now.to_i - time.to_time.to_i
days = (seconds / (24 * 60 * 60)).to_i
hours = (seconds / (60 * 60)).to_i
(hours > 24) and hours = hours % 24
minutes = (seconds / 60) - (hours * 60) - (days * 24 * 60)
time_ago = ''
(days > 0) and time_ago += "#{days} days, "
(hours > 0) and time_ago += "#{hours} hours, "
(days > 0 && hours > 0) and time_ago += 'and '
time_ago += "#{minutes % 60} minutes"

follows = get_follows(twitter, user)

puts "\n☕ ️Checking tweet counts for #{follows.size} follows since #{time.strftime('%F %R %z')}..."
follows_with_tweet_counts = {}
follows.each do |username|
  follows_with_tweet_counts[username] = tweets_over_time(twitter, username, time)
end

puts "\n\n👍 Done! #{user}'s most garrulous follows over #{time_ago} are:"
shown = 0
follows_with_tweet_counts.sort_by{ |k, v| v }.reverse.each do |k,v|
  if v > 0
    shown += 1
    puts "\t💬 #{'%-24.24s' % "#{k}:"} #{'%3.3s' % v}"
  end
end
if shown == 0
  puts "💤 Somehow, none of these #{follows.size} people have tweeted during this time period."
end
