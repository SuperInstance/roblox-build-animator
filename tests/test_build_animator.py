"""
Comprehensive test suite for BuildAnimator — Cinematic staggered construction.
Tests config defaults, stagger/BPM, sound mapping, queue management, patterns, module structure.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from conftest import LuaRunner

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA_SRC = os.path.join(REPO, "src", "init.lua")
LUA_PATTERNS = os.path.join(REPO, "src", "Patterns.lua")
runner = LuaRunner.shared()


def load():
    return runner.strip_and_load(LUA_SRC, "BuildAnimator")


def load_patterns():
    return runner.strip_and_load(LUA_PATTERNS, "Patterns")


class TestConfigDefaults:
    def test_default_part_tween_time(self):
        assert runner.run(load() + 'io.write(tostring(BuildAnimator.getConfig().PART_TWEEN_TIME))').strip() == "0.32"

    def test_default_stagger_delay(self):
        assert runner.run(load() + 'io.write(tostring(BuildAnimator.getConfig().STAGGER_DELAY))').strip() == "0.08"

    def test_default_animation_style(self):
        assert runner.run(load() + 'io.write(tostring(BuildAnimator.getConfig().ANIMATION_STYLE))').strip() == "drop"

    def test_default_max_concurrent(self):
        assert runner.run(load() + 'io.write(tostring(BuildAnimator.getConfig().MAX_CONCURRENT_ANIMATIONS))').strip() == "30"

    def test_default_landing_particle_count(self):
        assert runner.run(load() + 'io.write(tostring(BuildAnimator.getConfig().LANDING_PARTICLE_COUNT))').strip() == "8"

    def test_default_sort_mode(self):
        assert runner.run(load() + 'io.write(tostring(BuildAnimator.getConfig().BATCH_SORT_MODE))').strip() == "height_then_distance"

    def test_default_drop_height(self):
        assert runner.run(load() + 'io.write(tostring(BuildAnimator.getConfig().DROP_HEIGHT))').strip() == "10"

    def test_config_is_shallow_copy(self):
        code = load() + """
        local c1 = BuildAnimator.getConfig()
        c1.PART_TWEEN_TIME = 999
        io.write(tostring(BuildAnimator.getConfig().PART_TWEEN_TIME))
        """
        assert runner.run(code).strip() == "0.32"

    def test_reset_config(self):
        code = load() + """
        BuildAnimator.configure({PART_TWEEN_TIME=5.0, STAGGER_DELAY=1.0})
        BuildAnimator.resetConfig()
        local c = BuildAnimator.getConfig()
        io.write(tostring(c.PART_TWEEN_TIME) .. "," .. tostring(c.STAGGER_DELAY))
        """
        assert runner.run(code).strip() == "0.32,0.08"

    def test_configure_override(self):
        code = load() + """
        BuildAnimator.configure({PART_TWEEN_TIME=0.5})
        io.write(tostring(BuildAnimator.getConfig().PART_TWEEN_TIME))
        """
        assert runner.run(code).strip() == "0.5"


class TestStaggerBPM:
    def test_stagger_120_bpm(self):
        code = load() + 'io.write(string.format("%.6f", BuildAnimator.getStagger(120)))'
        assert runner.run(code).strip() == "0.062500"

    def test_stagger_90_bpm(self):
        code = load() + 'io.write(string.format("%.6f", BuildAnimator.getStagger(90)))'
        result = float(runner.run(code).strip())
        assert abs(result - 0.083333) < 0.0001

    def test_stagger_60_bpm(self):
        code = load() + 'io.write(string.format("%.6f", BuildAnimator.getStagger(60)))'
        assert runner.run(code).strip() == "0.125000"

    def test_stagger_zero_bpm_returns_default(self):
        code = load() + 'io.write(tostring(BuildAnimator.getStagger(0)))'
        assert runner.run(code).strip() == "0.08"

    def test_stagger_negative_bpm_returns_default(self):
        code = load() + 'io.write(tostring(BuildAnimator.getStagger(-10)))'
        assert runner.run(code).strip() == "0.08"

    def test_stagger_non_number_returns_default(self):
        code = load() + 'io.write(tostring(BuildAnimator.getStagger(nil)))'
        assert runner.run(code).strip() == "0.08"


class TestSoundIDMapping:
    def test_sound_stone_material(self):
        code = load() + """
        BuildAnimator.playPlacementSound(Enum.Material.Slate, Vector3.new(0,0,0))
        io.write("ok")
        """
        assert runner.run(code).strip() == "ok"

    def test_sound_wood_material(self):
        code = load() + 'BuildAnimator.playPlacementSound(Enum.Material.Wood, Vector3.new(0,0,0))\nio.write("ok")'
        assert runner.run(code).strip() == "ok"

    def test_sound_metal_material(self):
        code = load() + 'BuildAnimator.playPlacementSound(Enum.Material.Metal, Vector3.new(0,0,0))\nio.write("ok")'
        assert runner.run(code).strip() == "ok"

    def test_sound_glass_material(self):
        code = load() + 'BuildAnimator.playPlacementSound(Enum.Material.Glass, Vector3.new(0,0,0))\nio.write("ok")'
        assert runner.run(code).strip() == "ok"

    def test_sound_neon_material(self):
        code = load() + 'BuildAnimator.playPlacementSound(Enum.Material.Neon, Vector3.new(0,0,0))\nio.write("ok")'
        assert runner.run(code).strip() == "ok"

    def test_sound_default_material(self):
        code = load() + 'BuildAnimator.playPlacementSound(Enum.Material.Plastic, Vector3.new(0,0,0))\nio.write("ok")'
        assert runner.run(code).strip() == "ok"

    def test_sound_diamondplate(self):
        code = load() + 'BuildAnimator.playPlacementSound(Enum.Material.DiamondPlate, Vector3.new(0,0,0))\nio.write("ok")'
        assert runner.run(code).strip() == "ok"

    def test_burst_does_not_crash(self):
        code = load() + 'BuildAnimator.burst(Vector3.new(0,0,0), Color3.new(1,0,0))\nio.write("ok")'
        assert runner.run(code).strip() == "ok"


class TestQueueManagement:
    def test_initial_stats(self):
        code = load() + """
        local s = BuildAnimator.getStats()
        io.write(tostring(s.active) .. "," .. tostring(s.queued) .. "," .. tostring(s.maxConcurrent))
        """
        assert runner.run(code).strip() == "0,0,30"

    def test_clear_queue_empty(self):
        code = load() + 'io.write(tostring(BuildAnimator.clearQueue()))'
        assert runner.run(code).strip() == "0"

    def test_get_stats_returns_table(self):
        code = load() + 'io.write(type(BuildAnimator.getStats()))'
        assert runner.run(code).strip() == "table"

    def test_get_stats_has_fields(self):
        code = load() + """
        local s = BuildAnimator.getStats()
        io.write(tostring(s.active ~= nil) .. "," .. tostring(s.queued ~= nil) .. "," .. tostring(s.maxConcurrent ~= nil))
        """
        assert runner.run(code).strip() == "true,true,true"


class TestModuleStructure:
    def test_module_is_table(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator))').strip() == "table"

    def test_has_play(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.play))').strip() == "function"

    def test_has_playInTime(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.playInTime))').strip() == "function"

    def test_has_animatePart(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.animatePart))').strip() == "function"

    def test_has_burst(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.burst))').strip() == "function"

    def test_has_configure(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.configure))').strip() == "function"

    def test_has_resetConfig(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.resetConfig))').strip() == "function"

    def test_has_getConfig(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.getConfig))').strip() == "function"

    def test_has_clearQueue(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.clearQueue))').strip() == "function"

    def test_has_getStats(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.getStats))').strip() == "function"

    def test_has_getStagger(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.getStagger))').strip() == "function"

    def test_has_playPlacementSound(self):
        assert runner.run(load() + 'io.write(type(BuildAnimator.playPlacementSound))').strip() == "function"

    def test_has_OnComplete(self):
        assert runner.run(load() + 'io.write(tostring(BuildAnimator.OnComplete ~= nil))').strip() == "true"

    def test_has_OnPartRevealed(self):
        assert runner.run(load() + 'io.write(tostring(BuildAnimator.OnPartRevealed ~= nil))').strip() == "true"


class TestPatterns:
    def test_patterns_is_table(self):
        assert runner.run(load_patterns() + 'io.write(type(Patterns))').strip() == "table"

    def test_has_rise(self):
        assert runner.run(load_patterns() + 'io.write(tostring(Patterns.rise ~= nil))').strip() == "true"

    def test_has_drop(self):
        assert runner.run(load_patterns() + 'io.write(tostring(Patterns.drop ~= nil))').strip() == "true"

    def test_has_cascade(self):
        assert runner.run(load_patterns() + 'io.write(tostring(Patterns.cascade ~= nil))').strip() == "true"

    def test_has_scaleIn(self):
        assert runner.run(load_patterns() + 'io.write(tostring(Patterns.scaleIn ~= nil))').strip() == "true"

    def test_has_fade(self):
        assert runner.run(load_patterns() + 'io.write(tostring(Patterns.fade ~= nil))').strip() == "true"

    def test_has_weather(self):
        assert runner.run(load_patterns() + 'io.write(tostring(Patterns.weather ~= nil))').strip() == "true"

    def test_get_by_name(self):
        assert runner.run(load_patterns() + 'io.write(tostring(Patterns.get("rise") ~= nil))').strip() == "true"

    def test_get_unknown_returns_nil(self):
        assert runner.run(load_patterns() + 'io.write(tostring(Patterns.get("nonexistent")))').strip() == "nil"

    def test_list_returns_names(self):
        code = load_patterns() + 'io.write(table.concat(Patterns.list(), ","))'
        result = runner.run(code).strip()
        names = result.split(",")
        for expected in ["cascade", "drop", "fade", "rise", "scaleIn", "weather"]:
            assert expected in names

    def test_extend_merges_overrides(self):
        code = load_patterns() + """
        local e = Patterns.extend("rise", {PART_TWEEN_TIME=0.99})
        io.write(tostring(e.PART_TWEEN_TIME))
        """
        assert runner.run(code).strip() == "0.99"

    def test_extend_keeps_base(self):
        code = load_patterns() + """
        local e = Patterns.extend("rise", {PART_TWEEN_TIME=0.99})
        io.write(tostring(e.ANIMATION_STYLE))
        """
        assert runner.run(code).strip() == "rise"

    def test_extend_unknown_errors(self):
        code = load_patterns() + """
        local ok = pcall(function() Patterns.extend("nope", {}) end)
        io.write(tostring(ok))
        """
        assert runner.run(code).strip() == "false"

    def test_rise_pattern_style(self):
        code = load_patterns() + 'io.write(tostring(Patterns.rise.ANIMATION_STYLE))'
        assert runner.run(code).strip() == "rise"

    def test_drop_pattern_height(self):
        code = load_patterns() + 'io.write(tostring(Patterns.drop.DROP_HEIGHT))'
        assert runner.run(code).strip() == "12"
