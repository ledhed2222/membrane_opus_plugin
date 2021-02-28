defmodule Membrane.Opus.Parser do
  @moduledoc """
  Parses a raw incoming Opus stream and adds caps information, as well as metadata.

  Adds the following metadata:

  duration :: non_neg_integer()
    Number of nanoseconds encoded in this packet
  """

  use Membrane.Filter

  alias __MODULE__.{Delimitation, FrameLengths}
  alias Membrane.{Buffer, Opus, RemoteStream}
  alias Membrane.Opus.Util

  def_options delimitation: [
                spec: Delimitation.delimitation_t(),
                default: :keep,
                description: """
                If input is delimited (as indicated by the `self_delimiting?`
                field in %Opus) and `:undelimit` is selected, will remove delimiting.

                If input is not delimited and `:delimit` is selected, will add delimiting.

                If `:keep` is selected, will not change delimiting.

                Otherwise will act like `:keep`.

                See https://tools.ietf.org/html/rfc6716#appendix-B for details
                on the self-delimiting Opus format.
                """
              ],
              force_reading_input_as_delimited?: [
                spec: boolean(),
                default: false,
                description: """
                If you know that the input is self-delimited but you're reading from
                some element that isn't sending the correct structure, you can set this
                to true to force the Parser to assume the input is self-delimited and
                ignore upstream caps information on self-delimitation.
                """
              ]

  def_input_pad :input,
    demand_unit: :buffers,
    caps: [
      Opus,
      {RemoteStream, type: :packetized, content_format: one_of([Opus, nil])}
    ]

  def_output_pad :output, caps: Opus

  @impl true
  def handle_init(%__MODULE__{} = options) do
    state =
      options
      |> Map.from_struct()
      |> Map.merge(%{
        input_delimited?: options.force_reading_input_as_delimited?,
        buffer: <<>>
      })

    {:ok, state}
  end

  @impl true
  def handle_demand(:output, bufs, :buffers, _ctx, state) do
    {{:ok, demand: {:input, bufs}}, state}
  end

  @impl true
  def handle_caps(:input, caps, _ctx, state) when not state.force_reading_input_as_delimited? do
    {:ok, %{state | input_delimited?: caps.self_delimiting?}}
  end

  @impl true
  def handle_process(:input, %Buffer{payload: data}, _ctx, state) do
    {delimitation_processor, self_delimiting?} =
      Delimitation.get_processor(state.delimitation, state.input_delimited?)

    {buffer, packets, channels} =
      maybe_parse(state.buffer <> data, state.input_delimited?, delimitation_processor)

    packet_actions =
      if length(packets) > 0 do
        [
          caps:
            {:output,
             %Opus{
               channels: channels,
               self_delimiting?: self_delimiting?
             }},
          buffer: {:output, packets}
        ]
      else
        []
      end

    {{:ok, packet_actions ++ [redemand: :output]}, %{state | buffer: buffer}}
  end

  @spec maybe_parse(
          data :: binary,
          input_delimited? :: boolean,
          processor :: Delimitation.processor_t(),
          packets :: [Buffer.t()],
          channels :: 0..2
        ) :: {remaining_buffer :: binary, packets :: [Buffer.t()], channels :: 0..2}
  defp maybe_parse(data, input_delimited?, processor, packets \\ [], channels \\ 0)

  defp maybe_parse(data, input_delimited?, processor, packets, channels)
       when byte_size(data) > 0 do
    with {:ok, configuration_number, stereo_flag, frame_packing} <- Util.parse_toc_byte(data),
         channels <- max(channels, Util.parse_channels(stereo_flag)),
         {:ok, _mode, _bandwidth, frame_duration} <-
           Util.parse_configuration(configuration_number),
         {:ok, header_size, frame_lengths, padding_size} <-
           FrameLengths.parse(frame_packing, data, input_delimited?),
         expected_packet_size <- header_size + Enum.sum(frame_lengths) + padding_size,
         <<_raw_packet::binary-size(expected_packet_size), rest::binary>> <- data do
      packet = %Buffer{
        payload: processor.process(data, frame_lengths, header_size),
        metadata: %{
          duration: elapsed_time(frame_lengths, frame_duration)
        }
      }

      maybe_parse(
        rest,
        input_delimited?,
        processor,
        [packet | packets],
        channels
      )
    else
      _ ->
        {data, packets |> Enum.reverse(), channels}
    end
  end

  defp maybe_parse(data, _input_delimited?, _processor, packets, channels) do
    {data, packets |> Enum.reverse(), channels}
  end

  @spec elapsed_time(frame_lengths :: [non_neg_integer], frame_duration :: pos_integer) ::
          elapsed_time :: Membrane.Time.non_neg_t()
  defp elapsed_time(frame_lengths, frame_duration) do
    # if a frame has length 0 it indicates a dropped frame and should not be
    # included in this calc
    present_frames = frame_lengths |> Enum.count(fn length -> length > 0 end)
    present_frames * frame_duration
  end
end
