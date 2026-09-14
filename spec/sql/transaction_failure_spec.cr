require "../spec_helper"

module TransactionFailureSpec
  class InjectedFailure < Exception
  end

  # Fail one transaction-control statement before it reaches PostgreSQL.
  # Fiber scoping keeps the injection isolated from other spec activity.
  FAILURES = {} of Fiber => String

  def self.fail_next(statement : String, &)
    FAILURES[Fiber.current] = statement
    yield
  ensure
    FAILURES.delete(Fiber.current)
  end
end

module Lustra::SQL
  def execute(connection_name : String, sql)
    if statement = TransactionFailureSpec::FAILURES[Fiber.current]?
      if sql.to_s.starts_with?(statement)
        TransactionFailureSpec::FAILURES.delete(Fiber.current)
        raise TransactionFailureSpec::InjectedFailure.new("injected #{statement} failure")
      end
    end
    previous_def
  end
end

describe "Transaction failure boundaries" do
  it "clears transaction state when BEGIN fails before the body runs" do
    Lustra::SQL::ConnectionPool.with_connection("default") do |connection|
      body_calls = 0
      begin
        expect_raises(TransactionFailureSpec::InjectedFailure, "injected BEGIN failure") do
          TransactionFailureSpec.fail_next("BEGIN") do
            Lustra::SQL.transaction { body_calls += 1 }
          end
        end

        body_calls.should eq(0)
        connection._in_transaction?.should be_false

        Lustra::SQL.transaction do |next_connection|
          next_connection.should be(connection)
          next_connection._in_transaction?.should be_true
          body_calls += 1
        end
        body_calls.should eq(1)
      ensure
        # Prevent the reproduced stale flag from contaminating other specs.
        connection._in_transaction = false
        connection.exec_all("ROLLBACK")
      end
    end
  end

  it "does not replay the transaction body after a driver connection loss" do
    body_calls = 0
    callback_calls = 0
    failure = nil.as(Exception?)

    begin
      Lustra::SQL.transaction do |connection|
        body_calls += 1
        Lustra::SQL.after_commit { callback_calls += 1 }
        # ConnectionLost closes its resource, just as a driver failure does.
        raise DB::ConnectionLost.new(connection) if body_calls == 1
      end
    rescue e
      failure = e
    end

    body_calls.should eq(1)
    callback_calls.should eq(0)
    failure.should be_a(DB::ConnectionLost)
    Lustra::SQL.in_transaction?.should be_false

    Lustra::SQL.transaction { Lustra::SQL.after_commit { callback_calls += 1 } }
    callback_calls.should eq(1)
  end

  it "does not reconnect and replay nested connection work inside a transaction" do
    body_calls = 0
    query_calls = 0

    expect_raises(DB::ConnectionLost) do
      Lustra::SQL.transaction("secondary") do
        body_calls += 1
        Lustra::SQL::ConnectionPool.with_connection("secondary") do |connection|
          query_calls += 1
          raise DB::ConnectionLost.new(connection) if query_calls == 1
        end
      end
    end

    body_calls.should eq(1)
    query_calls.should eq(1)
    Lustra::SQL.in_transaction?("secondary").should be_false
  end

  it "rolls back an open transaction when COMMIT fails before reaching the server" do
    Lustra::SQL::ConnectionPool.with_connection("default") do |connection|
      callback_calls = 0
      begin
        expect_raises(TransactionFailureSpec::InjectedFailure, "injected COMMIT failure") do
          TransactionFailureSpec.fail_next("COMMIT") do
            Lustra::SQL.transaction do
              # Assign a transaction ID so the server's state can be inspected.
              connection.query_one("SELECT txid_current()", as: Int64)
              Lustra::SQL.after_commit { callback_calls += 1 }
            end
          end
        end

        callback_calls.should eq(0)
        connection._in_transaction?.should be_false
        connection.query_one("SELECT txid_current_if_assigned()", as: Int64?).should be_nil
      ensure
        connection._in_transaction = false
        connection.exec_all("ROLLBACK")
      end
    end
  end
end
