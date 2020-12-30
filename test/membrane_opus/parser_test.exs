defmodule Membrane.Opus.Parser.ParserTest do
  use ExUnit.Case, async: true

  import Membrane.Time
  import Membrane.Testing.Assertions

  alias Membrane.Opus.Parser
  alias Membrane.{Opus, Buffer}
  alias Membrane.Testing.{Source, Sink, Pipeline}

  @fixtures [
    %{
      desc: "dropped packet, code 0",
      normal: <<4>>,
      delimitted: <<4, 0>>,
      channels: 2,
      duration: 0
    },
    %{
      desc: "code 1",
      normal: <<121, 0, 0, 0, 0>>,
      delimitted: <<121, 2, 0, 0, 0, 0>>,
      channels: 1,
      duration: 40 |> milliseconds()
    },
    %{
      desc: "code 2",
      normal: <<198, 1, 0, 0, 0, 0>>,
      delimitted: <<198, 1, 3, 0, 0, 0, 0>>,
      channels: 2,
      duration: 5 |> milliseconds()
    },
    %{
      desc: "code 3 cbr, no padding",
      normal: <<199, 3, 0, 0, 0>>,
      delimitted: <<199, 3, 1, 0, 0, 0>>,
      channels: 2,
      duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
    },
    %{
      desc: "code 3 cbr, padding",
      normal: <<199, 67, 2, 0, 0, 0, 0, 0>>,
      delimitted: <<199, 67, 2, 1, 0, 0, 0, 0, 0>>,
      channels: 2,
      duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
    },
    %{
      desc: "code 3 vbr, no padding",
      normal: <<199, 131, 1, 2, 0, 0, 0, 0>>,
      delimitted: <<199, 131, 1, 2, 1, 0, 0, 0, 0>>,
      channels: 2,
      duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
    },
    %{
      desc: "code 3 vbr, no padding, long length",
      normal:
        <<199, 131, 253, 0, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0,
          0, 3, 3, 3>>,
      delimitted:
        <<199, 131, 253, 0, 2, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
          0, 0, 3, 3, 3>>,
      channels: 2,
      duration: (7.5 * 1_000_000) |> trunc() |> nanoseconds()
    }
  ]

  test "non-self-delimiting input and output" do
    inputs =
      @fixtures
      |> Enum.map(fn fixture -> fixture.normal end)

    options = %Pipeline.Options{
      elements: [
        source: %Source{output: inputs},
        parser: Parser,
        sink: Sink
      ]
    }

    {:ok, pipeline} = Pipeline.start_link(options)
    Pipeline.play(pipeline)

    assert_start_of_stream(pipeline, :sink)

    @fixtures
    |> Enum.each(fn fixture ->
      expected_caps = %Opus{channels: fixture.channels, self_delimiting?: false}
      assert_sink_caps(pipeline, :sink, ^expected_caps)

      expected_buffer = %Buffer{payload: fixture.normal, metadata: %{duration: fixture.duration}}
      assert_sink_buffer(pipeline, :sink, ^expected_buffer)
    end)

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)
  end

  test "non-self-delimiting input, self-delimiting output" do
    inputs =
      @fixtures
      |> Enum.map(fn fixture -> fixture.normal end)

    options = %Pipeline.Options{
      elements: [
        source: %Source{output: inputs},
        parser: %Parser{delimitation: :delimit},
        sink: Sink
      ]
    }

    {:ok, pipeline} = Pipeline.start_link(options)
    Pipeline.play(pipeline)

    assert_start_of_stream(pipeline, :sink)

    @fixtures
    |> Enum.each(fn fixture ->
      expected_caps = %Opus{channels: fixture.channels, self_delimiting?: true}
      assert_sink_caps(pipeline, :sink, ^expected_caps)

      expected_buffer = %Buffer{
        payload: fixture.delimitted,
        metadata: %{duration: fixture.duration}
      }

      assert_sink_buffer(pipeline, :sink, ^expected_buffer)
    end)

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)
  end

  test "self-delimiting input and output" do
    inputs =
      @fixtures
      |> Enum.map(fn fixture -> fixture.delimitted end)

    options = %Pipeline.Options{
      elements: [
        source: %Source{output: inputs},
        parser: %Parser{input_delimitted?: true},
        sink: Sink
      ]
    }

    {:ok, pipeline} = Pipeline.start_link(options)
    Pipeline.play(pipeline)

    assert_start_of_stream(pipeline, :sink)

    @fixtures
    |> Enum.each(fn fixture ->
      expected_caps = %Opus{channels: fixture.channels, self_delimiting?: true}
      assert_sink_caps(pipeline, :sink, ^expected_caps)

      expected_buffer = %Buffer{
        payload: fixture.delimitted,
        metadata: %{duration: fixture.duration}
      }

      assert_sink_buffer(pipeline, :sink, ^expected_buffer)
    end)

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)
  end

  test "self-delimiting input, non-self-delimiting output" do
    inputs =
      @fixtures
      |> Enum.map(fn fixture -> fixture.delimitted end)

    options = %Pipeline.Options{
      elements: [
        source: %Source{output: inputs},
        parser: %Parser{delimitation: :undelimit, input_delimitted?: true},
        sink: Sink
      ]
    }

    {:ok, pipeline} = Pipeline.start_link(options)
    Pipeline.play(pipeline)

    assert_start_of_stream(pipeline, :sink)

    @fixtures
    |> Enum.each(fn fixture ->
      expected_caps = %Opus{channels: fixture.channels, self_delimiting?: false}
      assert_sink_caps(pipeline, :sink, ^expected_caps)

      expected_buffer = %Buffer{payload: fixture.normal, metadata: %{duration: fixture.duration}}
      assert_sink_buffer(pipeline, :sink, ^expected_buffer)
    end)

    assert_end_of_stream(pipeline, :sink)
    refute_sink_buffer(pipeline, :sink, _, 0)
  end
end
