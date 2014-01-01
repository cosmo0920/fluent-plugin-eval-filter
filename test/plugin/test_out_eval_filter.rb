require 'helper'

class EvalFilterTest < Test::Unit::TestCase

  def setup
    Fluent::Test.setup
  end

  def create_driver(conf, tag = 'test')
    Fluent::Test::OutputTestDriver.new(Fluent::EvalFilterOutput, tag).configure(conf)
  end

  def test_configure
    assert_raise(Fluent::ConfigError) do
      create_driver('')
    end
  end

  def test_remove_tag_prefix
    d = create_driver(%[
      remove_tag_prefix t1
      filter1 tag
    ], 't1.t2.t3')

    d.run { d.emit({}) }

    emits = d.emits
    assert_equal 1, emits.size
    p emits[0]
    assert_equal 't2.t3', emits[0][0]
  end

  def test_remove_tag_suffix
    d = create_driver(%[
      remove_tag_suffix t3
      filter1 tag
    ], 't1.t2.t3')

    d.run { d.emit({}) }

    emits = d.emits
    assert_equal 1, emits.size
    p emits[0]
    assert_equal 't1.t2', emits[0][0]
  end

  def test_add_tag_prefix
    d = create_driver(%[
      add_tag_prefix t0
      filter1 tag
    ], 't1.t2.t3')

    d.run { d.emit({}) }

    emits = d.emits
    assert_equal 1, emits.size
    p emits[0]
    assert_equal 't0.t1.t2.t3', emits[0][0]
  end

  def test_add_tag_suffix
    d = create_driver(%[
      add_tag_suffix t4
      filter1 tag
    ], 't1.t2.t3')

    d.run { d.emit({}) }

    emits = d.emits
    assert_equal 1, emits.size
    p emits[0]
    assert_equal 't1.t2.t3.t4', emits[0][0]
  end

  def test_handle_tag_all
    d = create_driver(%[
      remove_tag_prefix t1
      remove_tag_suffix t3
      add_tag_prefix t4
      add_tag_suffix t5
      filter1 tag
    ], 't1.t2.t3')

    d.run { d.emit({}) }

    emits = d.emits
    assert_equal 1, emits.size
    p emits[0]
    assert_equal 't4.t2.t5', emits[0][0]
  end

  def test_drop_all_filter
    d = create_driver(%[
      filter1 nil
    ])

    d.run { d.emit({}) }

    emits = d.emits
    p emits
    assert_equal 0, emits.size
  end

  def test_modify_record_filter
    d = create_driver(%[
      filter1 record.merge!({'key' => 'value'})
    ])

    d.run { d.emit({}) }

    emits = d.emits
    assert_equal 1, emits.size
    p emits[0]
    assert_equal 'test', emits[0][0]
    assert_equal 1, emits[0][2].size
    assert_equal true, emits[0][2].key?('key')
    assert_equal 'value', emits[0][2]['key']
  end

  def test_replace_all_filter
    d = create_driver(%[
      filter1 nil
      filter2 ['tag', 0, {'key' => 'value'}]
    ])

    d.run { d.emit({}) }

    emits = d.emits
    assert_equal 1, emits.size
    p emits[0]
    assert_equal 'tag', emits[0][0]
    assert_equal 0, emits[0][1]
    assert_equal 1, emits[0][2].size
    assert_equal true, emits[0][2].key?('key')
    assert_equal 'value', emits[0][2]['key']
  end

  def test_conditional_filter
    d = create_driver(%[
      filter1 [['http', tag].join('.'), record] if /^http:/.match(record['url'])
      filter2 (record['secure'] = true; [['https', tag].join('.'), record]) if /^https:/.match(record['url'])
    ])

    d.run do
      d.emit({'url' => 'http://example.com/'})
      d.emit({'url' => 'https://example.com/'})
      d.emit({'url' => 'ftp://example.com/'})
    end

    emits = d.emits
    assert_equal 2, emits.size
    p emits[0]
    assert_equal 'http.test', emits[0][0]
    assert_equal 1, emits[0][2].size
    assert_equal true, emits[0][2].key?('url')
    assert_equal 'http://example.com/', emits[0][2]['url']
    p emits[1]
    assert_equal 'https.test', emits[1][0]
    assert_equal 2, emits[1][2].size
    assert_equal true, emits[1][2].key?('url')
    assert_equal 'https://example.com/', emits[1][2]['url']
    assert_equal true, emits[1][2].key?('secure')
    assert_equal true, emits[1][2]['secure']
  end

  def test_reference_to_an_instance_variable_filter
    hostname = `hostname -s`.chomp
    d = create_driver(%[
      config1 @hostname = `hostname -s`.chomp
      filter1 [tag, @hostname].join('.')
    ])

    d.run { d.emit({}) }

    emits = d.emits
    assert_equal 1, emits.size
    p emits[0]
    assert_equal "test.#{hostname}", emits[0][0]
  end

end
