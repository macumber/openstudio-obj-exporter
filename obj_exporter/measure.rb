# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# start the measure
class ObjExporter < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Obj Exporter"
  end

  # human readable description
  def description
    return "Exports the OpenStudio model in Wavefront OBJ format for viewing in common 3D engines."
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end
  
  def getVertexIndex(vertex, allVertices, tol = 0.001)
    allVertices.each_index do |i|
      if OpenStudio::getDistance(vertex, allVertices[i]) < tol
        return i + 1
      end
    end
    allVertices << vertex
    return (allVertices.length)
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    z = OpenStudio::Vector.new(3)
    z[0] = 0
    z[1] = 0
    z[2] = 1
    
    allVertices = []
    objVertices = ""
    objFaces = ""

    model.getSurfaces.each do |surface|

      surfaceVertices = surface.vertices
      t = OpenStudio::Transformation::alignFace(surfaceVertices)
      r = t.rotationMatrix
      tInv = t.inverse
      
      siteTransformation = OpenStudio::Transformation.new
      planarSurfaceGroup = surface.planarSurfaceGroup
      if not planarSurfaceGroup.empty?
        siteTransformation = planarSurfaceGroup.get.siteTransformation
      end
      
      surfaceVertices = tInv*surfaceVertices
      subSurfaceVertices = OpenStudio::Point3dVectorVector.new
      subSurfaces = surface.subSurfaces
      subSurfaces.each do |subSurface|
        subSurfaceVertices << tInv*subSurface.vertices
      end

      triangles = OpenStudio::computeTriangulation(surfaceVertices, subSurfaceVertices)
      if triangles.empty?
        runner.registerWarning("Failed to triangulate surface #{surface.name} with #{subSurfaces.size} sub surfaces")
      end
      
      objFaces += "#Surface #{surface.name}\n"
      triangles.each do |vertices|
        vertices = siteTransformation*t*vertices
        normal = siteTransformation.rotationMatrix*r*z

        indices = []
        vertices.each do |vertex|
          indices << getVertexIndex(vertex, allVertices)
        end
        
        objFaces += "f #{indices.join(' ')}\n"
      end
      
      subSurfaces.each do |subSurface|
     
        subSurfaceVertices = tInv*subSurface.vertices
        triangles = OpenStudio::computeTriangulation(subSurfaceVertices, OpenStudio::Point3dVectorVector.new)

        objFaces += "#SubSurface #{subSurface.name}\n"
        triangles.each do |vertices|
          vertices = siteTransformation*t*vertices
          normal = siteTransformation.rotationMatrix*r*z

          indices = []
          vertices.each do |vertex|
            indices << getVertexIndex(vertex, allVertices)  
          end    
          
          objFaces += "f #{indices.join(' ')}\n"
        end
      end
    end
    
    if objFaces.empty?
      runner.registerError("Model is empty, no output will be written")
      return false
    end

    # write object file
    obj_out_path = "./output.obj"
    File.open(obj_out_path, 'w') do |file|

      file << "# OpenStudio OBJ Export\n"
      allVertices.each do |v|
        file << "v #{v.x} #{v.z} #{-v.y}\n"
      end
      file << objFaces
      
      # make sure data is written to the disk one way or the other      
      begin
        file.fsync
      rescue
        file.flush
      end
    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getSpaces.size} spaces.")

    return true

  end
  
end

# register the measure to be used by the application
ObjExporter.new.registerWithApplication
