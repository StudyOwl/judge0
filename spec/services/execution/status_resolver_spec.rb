require "rails_helper"

RSpec.describe Execution::StatusResolver do
  it "maps isolate timeout to time limit exceeded" do
    status = described_class.call(status: "TO", exit_signal: nil, expected_output: nil, stdout: nil)

    expect(status).to eq(Status.tle)
  end

  it "maps isolate signal status to the matching runtime error" do
    status = described_class.call(status: "SG", exit_signal: 11, expected_output: nil, stdout: nil)

    expect(status).to eq(Status.sigsegv)
  end

  it "accepts output while ignoring trailing whitespace" do
    status = described_class.call(status: nil, exit_signal: nil, expected_output: "hello\n", stdout: "hello  \n")

    expect(status).to eq(Status.ac)
  end

  it "rejects mismatched output" do
    status = described_class.call(status: nil, exit_signal: nil, expected_output: "hello", stdout: "goodbye")

    expect(status).to eq(Status.wa)
  end
end
