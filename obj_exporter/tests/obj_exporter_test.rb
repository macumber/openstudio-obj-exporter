require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

require 'fileutils'

class ObjExporterTest < MiniTest::Test

  # def setup
  # end

  # def teardown
  # end
  
  def test_valid_measure
    measure = OpenStudio::BCLMeasure.new(File.dirname(__FILE__) + "/../")
    assert_equal("obj_exporter", measure.name)
    assert_equal("Obj Exporter", measure.displayName)
    assert_equal("Reporting.QAQC", measure.taxonomyTag)
  end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = ObjExporter.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(0, arguments.size)
  end

  def test_empty_model
    # create an instance of the measure
    measure = ObjExporter.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # check that there are no spaces
    assert_equal(0, model.getSpaces.size)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    current_dir = Dir.pwd
    run_dir = File.dirname(__FILE__) + "/output/empty_model"
    FileUtils.rm_rf(run_dir) if File.exists?(run_dir)
    FileUtils.mkdir_p(run_dir)
    Dir.chdir(run_dir)
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    assert_equal("Fail", result.value.valueName)
    
    Dir.chdir(current_dir)

    # check that there are still no spaces
    assert_equal(0, model.getSpaces.size)
    
    # check that no obj was written
    assert((not File.exists?(run_dir + "/output.obj")))
  end

  def test_example_model
    # create an instance of the measure
    measure = ObjExporter.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::exampleModel
    
    # check that there are spaces
    assert_equal(4, model.getSpaces.size)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)
    
    current_dir = Dir.pwd
    run_dir = File.dirname(__FILE__) + "/output/example_model"
    FileUtils.rm_rf(run_dir) if File.exists?(run_dir)
    FileUtils.mkdir_p(run_dir)
    Dir.chdir(run_dir)
    
    model.save("example_model.osm", true)
    
    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result
    assert_equal("Success", result.value.valueName)
    
    Dir.chdir(current_dir)

    # check that there is now 1 space
    assert_equal(4, model.getSpaces.size)

    # check that obj file is generated
    assert(File.exists?(run_dir + "/output.obj"))
  end

end
