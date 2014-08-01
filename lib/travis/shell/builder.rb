module Travis
  module Shell
    class Builder
      attr_reader :stack
      attr_accessor :options

      def initialize
        @stack = [Shell::Ast::Script.new]
        @options = {}
      end

      def sh # rename to node?
        stack.last
      end

      def to_sexp
        sh.to_sexp
      end

      def script(*args, &block)
        block = with_node(&block) if block
        sh.nodes << Shell::Ast::Script.new(*merge_options(args), &block)
      end

      def node(type, data = nil, *args)
        args = merge_options(args)
        if fold = args.last.delete(:fold)
          fold(fold) { node(type, data, *args) }
        else
          pos = args.last.delete(:pos)
          node = Shell::Ast::Cmd.new(type, data, *args)
          sh.nodes.insert(pos || -1, node)
        end
      end

      def raw(code, options = {})
        node :raw, code, options
      end

      def cmd(data, *args)
        node :cmd, data, *args
      end

      def set(name, value, options = {})
        node :set, [name, value], { assert: false, echo: true, timing: false }.merge(options)
      end

      def export(name, value, options = {})
        node :export, [name, value], { assert: false, echo: true, timing: false }.merge(options)
      end

      def echo(msg = '', options = {})
        msg.split("\n").each do |line|
          if line.empty?
            newline
          else
            node :echo, line, { assert: false, echo: false, timing: false }.merge(options)
          end
        end
      end

      def deprecate(msg)
        lines = msg.split("\n")
        lines.each.with_index do |line|
          node :echo, line, ansi: :red
        end
        newline(pos: lines.size)
      end

      def newline(options = {})
        node :newline, nil, { timing: false }.merge(options)
      end

      def terminate(result, message = nil)
        echo message if message
        cmd "travis_terminate #{result}"
      end

      def cd(path, options = {})
        node :cd, path, { assert: false, echo: true, timing: false }.merge(options)
      end

      def file(path, content, options = {})
        node :file, [content, path], { assert: false, echo: false, timing: false }.merge(options)
      end

      def chmod(mode, file, options = {})
        node :chmod, [mode, file], { timing: false }.merge(options)
      end

      def chown(owner, file, options = {})
        node :chown, [owner, file], { timing: false }.merge(options)
      end

      def mkdir(path, options = {})
        node :mkdir, path, { assert: !options[:recursive], echo: true, timing: false }.merge(options)
      end

      def cp(source, target, options = {})
        node :cp, [source, target], { assert: true, echo: true, timing: false }.merge(options)
      end

      def mv(source, target, options = {})
        node :mv, [source, target], { assert: true, echo: true, timing: false }.merge(options)
      end

      def rm(path, options = {})
        node :rm, path, { assert: !options[:force], timing: false }.merge(options)
      end

      def fold(name, options = {}, &block)
        args = merge_options(name)
        block = with_node(&block) if block
        node = Shell::Ast::Fold.new(*args, &block)
        sh.nodes.insert(options[:pos] || -1, node)
      end

      def if(*args, &block)
        block = with_node(&block) if block
        args = merge_options(args)
        then_ = args.last.delete(:then)
        else_ = args.last.delete(:else)

        node = Shell::Ast::If.new(*args, &block)
        node.last.cmd(then_, args.last) if then_
        node.last.else(else_, args.last) if else_
        sh.nodes << node
      end

      def then(&block)
        block = with_node(&block) if block
        yield self
      end

      def elif(*args, &block)
        block = with_node(&block) if block
        args = merge_options(args)
        sh.nodes.last.branches << Shell::Ast::Elif.new(*args, &block)
      end

      def else(*args, &block)
        block = with_node(&block) if block
        args = merge_options(args)
        sh.nodes.last.branches << Shell::Ast::Else.new(*args, &block)
        # rgt.cmd(*args) unless args.first.is_a?(Hash)
      end

      def with_options(options)
        options, @options = @options, options
        yield
        @options = options
      end

      private

        def merge_options(args)
          args = Array(args)
          options = args.last.is_a?(Hash) ? args.pop : {}
          options = self.options.merge(options)
          # options = { timing: true }.merge(options)
          args << options
        end

        def with_node
          ->(node) {
            stack.push(node)
            result = yield if block_given?
            stack.pop
            result
          }
        end
    end
  end
end
