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
