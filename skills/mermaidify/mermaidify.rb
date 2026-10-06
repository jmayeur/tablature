#!/usr/bin/env ruby
# Make a Mermaid flowchart from a .tab file.
#
#   mermaidify FILE.tab            Write Mermaid to stdout.
#   mermaidify --fence FILE.tab    Write it in a ```mermaid block.
#   mermaidify --update DOC.md     Fill each block between
#                                  <!-- mermaidify: path/to/file.tab --> and <!-- /mermaidify -->
#                                  Paths are relative to DOC.md.
#
# Uses only the Ruby standard library. Works with the macOS system Ruby (2.6).
require "yaml"

KINDS = %w[use do skill mcp script run ask wait parallel revert tab recipe].freeze
STATUSES = %w[ok fail inconclusive skipped].freeze
HUMAN = %w[ask].freeze
AGENT = %w[do skill recipe].freeze

class Mermaidify
  def initialize(path)
    @path = path
    @tab = YAML.safe_load(File.read(path))
    @actions = load_actions
    @lines = []
    @classes = Hash.new { |h, k| h[k] = [] }
    @ends = {}
  end

  def to_s
    @lines << "flowchart TD"
    @lines << "  START([start])"
    steps = @tab.fetch("steps")
    edge("START", node_id(steps.keys.first))
    draw_steps(steps, nil)
    @lines << "  END_([end])" if @ends["end"]
    @lines << "  FAIL_([fail])" if @ends["fail"]
    styles
    @lines.join("\n") + "\n"
  end

  private

  def load_actions
    ref = @tab["actions"]
    return ref || {} unless ref.is_a?(String)

    YAML.safe_load(File.read(File.join(File.dirname(@path), ref))).fetch("actions", {})
  end

  # Draw a list of steps. `branch` is nil at the top level, or the parallel
  # step's id inside a branch. A branch ends at its parent's join.
  def draw_steps(steps, branch)
    ids = steps.keys
    steps.each_with_index do |(id, step), i|
      following = ids[i + 1]
      if step["parallel"]
        draw_parallel(id, step)
      else
        node(id, step)
      end
      draw_routes(id, step, following, branch)
    end
  end

  def draw_parallel(id, step)
    need = step["need"] || "all"
    @lines << "  subgraph #{node_id(id)}[\"#{esc(id)} · parallel, need #{need}\"]"
    @lines << "    direction LR"
    step["parallel"].each do |name, steps|
      @lines << "    subgraph #{node_id("#{id}__#{name}")}[\"#{esc(name)}\"]"
      @lines << "      direction TB"
      draw_steps(steps, id)
      @lines << "    end"
    end
    @lines << "  end"
  end

  def draw_routes(id, step, following, branch)
    abort "#{@path}: step #{id}: use `route`, not `on` (YAML reads `on` as true)" if step.key?(true)
    on = step["route"] || {}
    on.each do |key, target|
      edge(node_id(id), target_id(target), key, dotted: %w[fail inconclusive].include?(key))
    end

    fallthrough = step["next"] || following
    # The last step of a branch joins its parent. The parent draws that edge.
    return if fallthrough.nil? && branch

    fallthrough ||= "end"
    verdicts = verdicts_of(step)
    covered = !verdicts.empty? && (verdicts - on.keys).empty?
    if !covered
      edge(node_id(id), target_id(fallthrough))
    elsif step["if"]
      edge(node_id(id), target_id(fallthrough), "skip", dotted: true)
    end
  end

  def node(id, step)
    kind = (step.keys & KINDS).first
    value = step[kind]
    detail = case kind
             when "wait" then "wait #{value}"
             when "revert" then "revert #{value}"
             when "tab", "script", "recipe" then "#{kind} #{File.basename(value.to_s)}"
             else "#{kind} #{short(value)}"
             end
    title = id.dup
    title = "🔒 #{title}" if step["gate"]
    title += " · max #{step['max']}" if step["max"]
    label = "#{esc(title)}<br/><small>#{esc(detail)}</small>"
    cat = category(kind, step)
    open, close = shape(kind, cat)
    @lines << "  #{node_id(id)}#{open}\"#{label}\"#{close}"
    @classes[cat] << node_id(id)
  end

  def shape(kind, cat)
    return ["[/", "\\]"] if kind == "revert"

    case cat
    when "human" then ["{", "}"]
    when "wait" then ["{{", "}}"]
    when "sub" then ["[[", "]]"]
    when "agent" then ["(", ")"]
    else ["[", "]"]
    end
  end

  # agent: a model does the work. det: deterministic. human: a person decides.
  def category(kind, step)
    kind = (@actions.fetch(step["use"], {}).keys & KINDS).first || "do" if kind == "use"
    return "human" if HUMAN.include?(kind)
    return "wait" if kind == "wait"
    return "sub" if kind == "tab"
    return "agent" if AGENT.include?(kind)

    "det"
  end

  def verdicts_of(step)
    return step["options"] if step["ask"] && step["options"]

    out = step["out"] || (step["use"] && @actions.fetch(step["use"], {})["out"]) || {}
    out["verdict"].is_a?(Array) ? out["verdict"] : []
  end

  def edge(from, to, label = nil, dotted: false)
    arrow = dotted ? "-.->" : "-->"
    arrow = dotted ? "-. #{esc(label)} .->" : "-- #{esc(label)} -->" if label
    @lines << "  #{from} #{arrow} #{to}"
  end

  def target_id(target)
    return node_id(target) unless %w[end fail].include?(target)

    @ends[target] = true
    target == "end" ? "END_" : "FAIL_"
  end

  # Prefix ids, so step names like "end" or "class" are not Mermaid keywords.
  def node_id(id)
    "s_#{id.to_s.gsub(/\W/, '_')}"
  end

  def short(value)
    text = value.to_s.lines.first.to_s.strip
    text.length > 32 ? "#{text[0, 31]}…" : text
  end

  def esc(text)
    text.to_s.gsub('"', "#quot;").gsub("<", "#lt;").gsub(">", "#gt;")
  end

  def styles
    @lines << "  classDef agent fill:#ede7f6,stroke:#5e35b1,color:#1a1a1a"
    @lines << "  classDef det fill:#e3f2fd,stroke:#1e88e5,color:#1a1a1a"
    @lines << "  classDef human fill:#fff3e0,stroke:#fb8c00,color:#1a1a1a"
    @lines << "  classDef wait fill:#eceff1,stroke:#546e7a,color:#1a1a1a"
    @lines << "  classDef sub fill:#e8f5e9,stroke:#43a047,color:#1a1a1a"
    @classes.each { |cls, ids| @lines << "  class #{ids.join(',')} #{cls}" }
  end
end

def update(doc)
  dir = File.dirname(doc)
  text = File.read(doc)
  pattern = %r{(<!-- mermaidify: (\S+) -->\n).*?(<!-- /mermaidify -->)}m
  count = 0
  text = text.gsub(pattern) do
    head, tab, tail = Regexp.last_match(1), Regexp.last_match(2), Regexp.last_match(3)
    count += 1
    "#{head}```mermaid\n#{Mermaidify.new(File.join(dir, tab))}```\n#{tail}"
  end
  File.write(doc, text)
  warn "#{doc}: #{count} diagram(s) updated"
end

case ARGV[0]
when "--update" then ARGV.drop(1).each { |doc| update(doc) }
when "--fence" then puts "```mermaid\n#{Mermaidify.new(ARGV.fetch(1))}```"
when nil, "-h", "--help" then puts File.read(__FILE__).lines.drop(1).take_while { |l| l.start_with?("#") }.map { |l| l.sub(/^# ?/, "") }
else print Mermaidify.new(ARGV[0])
end
