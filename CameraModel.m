%     Copyright (C) 2017 Imatest LLC
% 
%     This program is free software: you can redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
%     This program is distributed in the hope that it will be useful,
%     but WITHOUT ANY WARRANTY; without even the implied warranty of
%     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%     GNU General Public License for more details.
% 
%     You should have received a copy of the GNU General Public License
%     along with this program.  If not, see <http://www.gnu.org/licenses/>.

classdef CameraModel
   % CameraModel is a class which contains separate models for the lens, sensor and pipeline of the
   % imaging system. Its primary duty is to organize the data-flow between these components via its 
   % .simulate_exposure() method, as well as to provide some elements of "camera control tools".
   %
   % Camera Control Tools:
   %  .find_ae_time(scene, mode) - Basically, an auto-exposure routine which will suggest an
   %                               exposure time based on scene content. 
   
   
   properties
      sensorModel
      lensModel
      pipelineModel
   end
   
   
   methods
      
      function obj = CameraModel(imSize)
         % camModel = CameraModel(imSize)
         %
         % A new CameraModel uses the default constructions of each of the component Models. Since a
         % SensorModel (even the default one) requires a [height, width] input argument for
         % construction, so does CameraModel require that argument for construction.
         % 
         % The Default Camera is essentially:
         %  - a perfect lens
         %  - a 10-bit Bayer-GRBG sensor with no readout noise and gain of 1 DN/e
         %  - a pipeline which: 
         %     - demosaics
         %     - converts from 10-bit to 8-bit
         %     - applies an sRGB-like gamma of 2.2
         %     - 
         % This essentially means a perfect lens, a 10-bit sensor with no readout noise and gain of
         % 1 DN/e, and a processor which demosaics, applies an sRGB-like gamma, and produces 8-bit
         % output.
                  
         obj.sensorModel = SensorModel(imSize(1:2));
         obj.lensModel = LensModel();
         obj.pipelineModel = PipelineModel();
      end
      
      
      function processedIm = simulate_exposure(obj,scene,t)
         
         % - - Simulate optical system effects on the image - -         
         sensorPlaneRadiance = obj.lensModel.simulate(scene); % output is type double
         
         % - - Simulate sensor response to the image - -
         sensorData = obj.sensorModel.expose(sensorPlaneRadiance,t); % output is type uint16
         
         % - - Simulate camera's processing on the image - -
         processedIm = obj.pipelineModel.process(sensorData); % output may be uint8 or uint16
         
      end
      
      
      function tOpt = find_ae_time(obj, scene, mode)
         % tOpt = camodel.find_ae_time(scene)
         % tOpt = camodel.find_ae_time(scene, mode)
         %
         % Use a simple given model to find the optimal exposure time to capture the given scenev 
         % given the camera's current gain setting. (and in the future, aperture)
         %
         % - - Inputs - -
         % scene : currently values in units of photons per second per location
         % mode (optional) : a string, one of the following. Default: 'grayworld'
         %     'grayworld' : Exposure time will ensure the mean value of the scene equates to half
         %                    of the sensor's linear DN range
         %     'saturation' : Expsure time will ensure that the brightest value in the scene just
         %                    hits the saturation of the sensor's DN range (doesn't account for
         %                    finite well capacity).
         %
         % 
         %
         if nargin==2
            mode = 'grayworld';
         end
         
         switch mode
            case 'grayworld'
               tOpt = obj.sensorModel.maxDN / ...
                  (2*mean(double(scene(:)))*max(obj.sensorModel.qe)*obj.sensorModel.gain);
            
            case 'saturation'
               tOpt = obj.sensorModel.maxDN / ...
                  (max(double(scene(:)))*max(obj.sensorModel.qe)*obj.sensorModel.gain);
            otherwise
               error('Invalid auto-exposure mode string.')
         end
         
      end
      
   end
   
end % end classdef
