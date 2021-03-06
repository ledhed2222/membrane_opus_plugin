defmodule Membrane.Opus.BundlexProject do
  use Bundlex.Project

  def project() do
    [
      natives: natives(Bundlex.platform())
    ]
  end

  def natives(_platform) do
    [
      decoder: [
        sources: ["decoder.c"],
        libs: ["opus"],
        interface: :nif,
        preprocessor: Unifex
      ],
      encoder: [
        deps: [membrane_common_c: :membrane],
        sources: ["encoder.c"],
        libs: ["opus"],
        interface: :nif,
        preprocessor: Unifex
      ]
    ]
  end
end
