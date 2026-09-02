require "../spec_helper"

private class MessageLessSQLLogError < Exception
end

describe Lustra::SQL::Logger do
  it "includes the original exception type and message" do
    cause = Exception.new("connection failed")

    error = expect_raises(Lustra::SQL::Error, /Exception: connection failed.*Error caught, last query was:.*SELECT.*1/m) do
      Lustra::SQL.log_query("SELECT 1") { raise cause }
    end

    error.cause.should be(cause)
  end

  it "includes the original exception type when its message is nil" do
    cause = MessageLessSQLLogError.new

    error = expect_raises(Lustra::SQL::Error, /MessageLessSQLLogError.*Error caught, last query was:.*SELECT.*1/m) do
      Lustra::SQL.log_query("SELECT 1") { raise cause }
    end

    error.cause.should be(cause)
  end
end
