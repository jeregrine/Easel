defmodule EaselTerminalTest do
  use ExUnit.Case

  describe "frame_from_rgb/4" do
    test "maps luma to charset" do
      image = %{width: 2, height: 1, rgb: <<0, 0, 0, 255, 255, 255>>}

      frame = Easel.Terminal.frame_from_rgb(image, 2, 1, charset: " .#", fit: :fill)

      assert frame == " #"
    end

    test "supports inverted mapping" do
      image = %{width: 2, height: 1, rgb: <<0, 0, 0, 255, 255, 255>>}

      frame = Easel.Terminal.frame_from_rgb(image, 2, 1, charset: " .#", invert: true, fit: :fill)

      assert frame == "# "
    end

    test "contain fit letterboxes to preserve aspect ratio" do
      image = %{width: 4, height: 1, rgb: :binary.copy(<<255, 255, 255>>, 4)}

      frame =
        Easel.Terminal.frame_from_rgb(image, 2, 2, charset: " @", fit: :contain, cell_aspect: 1.0)

      assert frame == "@@\n  "
    end

    test "fill fit crops instead of stretching" do
      image = %{width: 4, height: 1, rgb: <<0, 0, 0, 255, 255, 255, 255, 255, 255, 0, 0, 0>>}

      frame =
        Easel.Terminal.frame_from_rgb(image, 2, 2, charset: " @", fit: :fill, cell_aspect: 1.0)

      assert frame == "@@\n@@"
    end

    test "ansi256 mode emits color escapes" do
      image = %{width: 1, height: 1, rgb: <<255, 0, 0>>}

      frame =
        Easel.Terminal.frame_from_rgb(image, 1, 1, charset: "#", color: :ansi256, fit: :fill)

      assert frame =~ "\e[38;5;"
      assert frame =~ "\e[0m"
    end

    test "auto contrast can lift dark pixels on dark themes" do
      image = %{width: 1, height: 1, rgb: <<0, 0, 0>>}

      frame =
        Easel.Terminal.frame_from_rgb(image, 1, 1,
          charset: " #",
          color: :ansi256,
          fit: :fill,
          theme: :dark,
          auto_contrast: true,
          dark_min_luma: 1.0
        )

      assert frame =~ "#"
    end

    test "auto contrast can be disabled" do
      image = %{width: 1, height: 1, rgb: <<0, 0, 0>>}

      frame =
        Easel.Terminal.frame_from_rgb(image, 1, 1,
          charset: " #",
          color: :ansi256,
          fit: :fill,
          theme: :dark,
          auto_contrast: false
        )

      assert frame =~ " "
      refute frame =~ "#"
    end

    test "braille mode renders unicode braille dots" do
      image = %{
        width: 2,
        height: 4,
        rgb: <<255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
      }

      assert Easel.Terminal.frame_from_rgb(image, 1, 1, mode: :braille, fit: :fill) == "⠁"
    end

    test "braille mode supports ansi256 color" do
      image = %{
        width: 2,
        height: 4,
        rgb: <<255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>
      }

      frame =
        Easel.Terminal.frame_from_rgb(image, 1, 1, mode: :braille, color: :ansi256, fit: :fill)

      assert frame =~ "\e[38;5;"
      assert frame =~ "⠁"
      assert frame =~ "\e[0m"
    end

    test "halfblock mode renders upper and lower blocks" do
      top_white_bottom_black = %{width: 1, height: 2, rgb: <<255, 255, 255, 0, 0, 0>>}
      bottom_white_top_black = %{width: 1, height: 2, rgb: <<0, 0, 0, 255, 255, 255>>}
      both_white = %{width: 1, height: 2, rgb: <<255, 255, 255, 255, 255, 255>>}

      assert Easel.Terminal.frame_from_rgb(top_white_bottom_black, 1, 1,
               mode: :halfblock,
               fit: :fill
             ) ==
               "▀"

      assert Easel.Terminal.frame_from_rgb(bottom_white_top_black, 1, 1,
               mode: :halfblock,
               fit: :fill
             ) ==
               "▄"

      assert Easel.Terminal.frame_from_rgb(both_white, 1, 1, mode: :halfblock, fit: :fill) == "█"
    end

    test "halfblock mode supports ansi256 foreground and background" do
      image = %{width: 1, height: 2, rgb: <<255, 0, 0, 0, 0, 255>>}

      frame =
        Easel.Terminal.frame_from_rgb(image, 1, 1, mode: :halfblock, color: :ansi256, fit: :fill)

      assert frame =~ "\e[38;5;"
      assert frame =~ "\e[48;5;"
      assert frame =~ "▀"
      assert frame =~ "\e[0m"
    end

    test "auto silhouette mode renders background as space" do
      if Easel.WX.available?() do
        image = %{width: 9, height: 19, rgb: :binary.copy(<<0, 0, 0>>, 9 * 19)}
        assert Easel.Terminal.frame_from_rgb(image, 1, 1) == " "
      end
    end

    test "auto silhouette mode picks a non-space glyph for solid foreground" do
      if Easel.WX.available?() do
        image = %{width: 9, height: 19, rgb: :binary.copy(<<255, 255, 255>>, 9 * 19)}
        frame = Easel.Terminal.frame_from_rgb(image, 1, 1)
        assert String.length(frame) == 1
        refute frame == " "
      end
    end

    test "raises when rgb buffer is too small" do
      image = %{width: 2, height: 1, rgb: <<0, 0, 0>>}

      assert_raise ArgumentError, ~r/rgb buffer is too small/, fn ->
        Easel.Terminal.frame_from_rgb(image, 2, 1)
      end
    end
  end
end
