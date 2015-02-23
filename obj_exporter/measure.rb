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
  
  def getSurfaceID(surface)
    result = "#{surface.iddObject.name}-#{surface.name}-#{surface.handle}"
    return result.gsub(' ', '_').gsub(':', '_').gsub('{', '').gsub('}', '')
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
    allSurfaceIDs = []

    # all planar surfaces
    model.getPlanarSurfaces.each do |surface|

      # handle sub surfaces later
      next if !surface.to_SubSurface.empty?
    
      surfaceID = getSurfaceID(surface)
      allSurfaceIDs << surfaceID
      
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
      
      subSurfaces = []
      subSurfaceVertices = OpenStudio::Point3dVectorVector.new
      if !surface.to_Surface.empty?
        subSurfaces = surface.to_Surface.get.subSurfaces
        subSurfaces.each do |subSurface|
          subSurfaceVertices << tInv*subSurface.vertices
        end
      end

      triangles = OpenStudio::computeTriangulation(surfaceVertices, subSurfaceVertices)
      if triangles.empty?
        runner.registerWarning("Failed to triangulate #{surface.iddObject.name} #{surface.name} with #{subSurfaces.size} sub surfaces")
      end
      
      objFaces += "##{surfaceID}\n"
      triangles.each do |vertices|
        vertices = siteTransformation*t*vertices
        normal = siteTransformation.rotationMatrix*r*z

        indices = []
        vertices.each do |vertex|
          indices << getVertexIndex(vertex, allVertices)
        end
        
        objFaces += "  usemtl #{surfaceID}\n"
        objFaces += "  f #{indices.join(' ')}\n"
      end
      
      # now do subSurfaces
      subSurfaces.each do |subSurface|
      
        subSurfaceID = getSurfaceID(subSurface)
        allSurfaceIDs << subSurfaceID
     
        subSurfaceVertices = tInv*subSurface.vertices
        triangles = OpenStudio::computeTriangulation(subSurfaceVertices, OpenStudio::Point3dVectorVector.new)

        objFaces += "##{subSurfaceID}\n"
        triangles.each do |vertices|
          vertices = siteTransformation*t*vertices
          normal = siteTransformation.rotationMatrix*r*z

          indices = []
          vertices.each do |vertex|
            indices << getVertexIndex(vertex, allVertices)  
          end    
          objFaces += "  usemtl #{subSurfaceID}\n"
          objFaces += "  f #{indices.join(' ')}\n"
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
      file << "mtllib output.mtl\n\n"
      file << "# Vertices\n"
      allVertices.each do |v|
        file << "v #{v.x} #{v.z} #{-v.y}\n"
      end
      file << "\n"
      file << "# Faces\n"
      file << objFaces
      
      # make sure data is written to the disk one way or the other      
      begin
        file.fsync
      rescue
        file.flush
      end
    end
    
    # write material file
    mtl_out_path = "./output.mtl"
    File.open(mtl_out_path, 'w') do |file|

      file << "# OpenStudio MTL Export\n"
      allSurfaceIDs.each do |surfaceID|
        file << "newmtl #{surfaceID}\n"
        file << "  Ka 1.000 0.000 0.000\n"
        file << "  Kd 1.000 0.000 0.000\n"
        file << "  Ks 1.000 0.000 0.000\n"
        file << "  Ns 0.0\n"
        file << "  d 0.5\n" # some implementations use 'd' others use 'Tr'
      end

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
