module Travis
  module Build
    class Script
      class Php < Script
        DEFAULTS = {
          php:      '5.3',
          composer: '--no-interaction --prefer-source'
        }

        def cache_slug
          super << "--php-" << config[:php].to_s
        end

        def use_directory_cache?
          super || data.cache?(:composer)
        end

        def export
          super
          set 'TRAVIS_PHP_VERSION', config[:php], echo: false
        end

        def setup
          super
          cmd "phpenv global #{config[:php]}", assert: true
        end

        def announce
          super
          cmd 'php --version'
          cmd 'composer --version' unless config[:php] == '5.2'
        end

        def before_install
          self.if '-f composer.json' do |sub|
            sub.cmd 'composer self-update', fold: 'before_install.update_composer' unless has_phar?
          end
        end

        def install
          self.if '-f composer.json' do |sub|
            directory_cache.add(sub, '~/.composer') if data.cache?(:composer)

            composer_exec = "composer" unless has_phar?
            composer_exec = "composer.phar" if has_phar?

            sub.cmd "#{composer_exec} install #{config[:composer_args]}".strip, fold: 'install.composer'
          end
        end

        def script
          cmd 'phpunit'
        end

        private

        def has_phar?
          self.if '-f composer.phar' do
            echo "Project contains composer.phar"
            return true
          end

          false
        end
      end
    end
  end
end
