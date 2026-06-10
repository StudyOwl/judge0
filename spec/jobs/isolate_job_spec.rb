require 'rails_helper'

RSpec.describe IsolateJob, type: :job do
  it "delegates execution to the execution engine" do
    expect(Execution::Engine).to receive(:call).with(123)

    described_class.new.perform(123)
  end
end
