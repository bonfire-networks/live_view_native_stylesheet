defmodule LiveViewNative.Stylesheet do
  defmacro __using__(format) do
    case LiveViewNative.Stylesheet.RulesParser.fetch(format) do
      {:ok, parser} ->
        quote do
          import LiveViewNative.Stylesheet.SheetParser, only: [sigil_SHEET: 2]
          import LiveViewNative.Stylesheet.RulesHelpers

          use unquote(parser)

          @format unquote(format)
          @before_compile LiveViewNative.Stylesheet
          @after_verify LiveViewNative.Stylesheet

          def compile_ast(class_or_list, target \\ [target: :all])
          def compile_ast(class_or_list, target: target) do
            class_or_list
            |> List.wrap()
            |> Enum.reduce(%{}, fn(class_name, class_map) ->
              case class(class_name, target: target) do
                {:unmatched, msg} -> class_map
                rules -> Map.put(class_map, class_name, List.wrap(rules))
              end
            end)
          end

          def compile_string(class_or_list, target \\ [target: :all]) do
            pretty = Application.get_env(:live_view_native_stylesheet, :pretty, false)

            compile_ast(class_or_list, target)
            |> inspect(limit: :infinity, charlists: :as_list, printable_limit: :infinity, pretty: pretty)
          end

          def __native_opts__ do
            %{format: unquote(format)}
          end
        end

      {:error, message} -> raise message
    end
  end


  def filename(module) do
    format = module.__native_opts__()[:format]

    module
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> Kernel.<>(".#{format}.styles")
  end

  def file_path(module) do
    Application.get_env(:live_view_native_stylesheet, :output)
    |> Path.join(filename(module))
  end

  def embed_stylesheet(module) do
    module
    |> file_path()
    |> File.read!()
    |> Phoenix.HTML.raw()
  end

  defmacro __before_compile__(env) do
    sheet_paths = Application.get_env(:live_view_native_stylesheet, :__sheet_paths__, [])
    sheet_path = Path.relative_to_cwd(env.file)

    Application.put_env(:live_view_native_stylesheet, :__sheet_paths__, [sheet_path | sheet_paths])

    quote do
      def class(_, _), do: {:unmatched, []}
    end
  end

  def __after_verify__(module) do
    compiled_sheet =
      LiveViewNative.Stylesheet.Extractor.run()
      |> module.compile_string()
    
    module
    |> file_path()
    |> File.write!(compiled_sheet)
  end
end
