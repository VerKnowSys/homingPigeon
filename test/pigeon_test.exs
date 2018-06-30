require Logger

alias Pigeon.Check
alias Pigeon.CheckResult
alias Pigeon.CheckNothingToReport
alias Pigeon.Domain
alias Pigeon.Http


defmodule PigeonTest do
  use ExUnit.Case
  doctest Pigeon

  test "Pigeon test of Http checks and results" do
    a_check = %Check{
      client: "żółtyżółw",
      domains: ["peter.centra.com"],
      pages: ["https://peter.centra.com/amspeter/", "https://peter.centra.com/aa"],
      expected: ["Username", "Password", "alabaster", "tralalala", "test"],
    }

    check_results = Http.process_pages a_check, [
      follow_redirects: true,
      timeout: a_check.timeout,
      cookies: a_check.cookies,
      headers: a_check.headers
    ]

    assert 2 == length check_results
    for result <- check_results do
      assert result != %CheckNothingToReport{}
      assert result.result == :failure
      assert String.contains?(Enum.join(result.errors, " "), "*alabaster*, *tralalala*, *test*")
      Logger.debug "Result: #{inspect result}"
    end
  end


  test "Pigeon test of Domain checks and results" do
    a_check = %Check{
      client: "żółtyżółw",
      domains: ["peter.centra.com", "peter.centraqa.com"],
      pages: []
    }

    check_results = Domain.process_domains a_check

    assert 2 == length check_results
    for result <- check_results do
      assert result == %CheckNothingToReport{}
      Logger.debug "Result: #{inspect result}"
    end

    wrong_check = %Check{
      client: "zielonyżółw",
      domains: ["idontexistcausetheresnome.centra.com"],
      pages: []
    }
    wrong_results = Domain.process_domains wrong_check

    assert 1 == length wrong_results
    for result <- wrong_results do
      assert result.result == :error
      assert String.contains? Enum.join(result.errors, " "), "No response for idontexistcausetheresnome.centra.com under DNS server:"
      Logger.debug "Result: #{inspect result}"
    end
  end
end
