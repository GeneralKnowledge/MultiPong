# Implementations

One directory per engine/framework. See [IMPLEMENTATION_GUIDE.md](../IMPLEMENTATION_GUIDE.md).

Unity / Unreal / GameMaker / RPG Maker: same basic game as `examples/`, not a richer build. See [ENGINE_WORKSPLIT.md](../ENGINE_WORKSPLIT.md) for AI vs human IDE handoff.

| Directory | Engine | Language | Status |
| --- | --- | --- | --- |
| [pygame/](pygame/) | Pygame | Python | Not started |
| [godot/](godot/) | Godot | GDScript | Not started |
| [unity/](unity/) | Unity | C# | Not started |
| [unreal-cpp/](unreal-cpp/) | Unreal Engine | C++ | Not started |
| [unreal-blueprints/](unreal-blueprints/) | Unreal Engine | Blueprints | Not started |
| [rpgmaker/](rpgmaker/) | RPG Maker | JavaScript | Not started |
| [gamemaker/](gamemaker/) | GameMaker | GML | Not started |
| [love2d/](love2d/) | Love2D | Lua | Not started |
| [phaser/](phaser/) | Phaser | TypeScript | Not started |
| [bevy/](bevy/) | Bevy | Rust | Not started |

Directories may remain stubs until someone ports to that engine. Adding a new engine = new folder + README, not a core architecture change.
