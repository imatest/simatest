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

classdef PipelineModel
   % The PipelineModel class is essentially a container for an ordered set of user-defined
   % operations to apply to the data array output of a SensorModel's .expose() method.
   %
   % An instance's .process() method does two things: 
   %  (1) Apply, in order, the operations indicated in its .processes property to the input data
   %  (2) Convert the output of the last process to the datatype indicated in the .outputType
   %        property. (Currently, only 'uint8' or 'uint16')
   %
   % The .process property should be a cell array of cell arrays. Each cell entry of the primary
   % array should itself be a cell array with form {@fcn_handle, arg1, arg2, ...}. 
   % Each of these will be used to apply the function indicated by fcn_handle to the data, in order.
   % Any supplemental arguments (i.e., data-independent parameters for the processing), should fill
   % out the remaining elements of the sub-cell array. 
   %
   % Functions used in this process should have signature: fcn(data,arg1,arg2,...)
   % Here, data is the data array (dimension and data type not guaranteed- it depends on the 
   % previous processing steps) output by the previous process. The only guarantee is that the input
   % to the first process will be a type uint16.
   %
   % Oftentimes these processes and their supplemental parameter values will need to be specifically
   % set to match the SensorModel used. E.g., Removing the specific offset applied by the sensor 
   % model, demosaicking the correct Bayer orientation of the sensor, scaling the data based on the
   % sensor's maxDN, etc.
   %
   % Some useful examples of processing functions are included as class static methods. These
   % include: 
   %     outData = demosaic(inData,bayerPhase)            Apply MATLAB improc toolbox demosiacing.
   %     outData = scale_max(inData,inMax,outMax)         Re-scale the data.
   %     outData = apply_gamma(inData,gamma,maxVal)       Apply a gamma power encoding to data.
   %
   % 
   % See also: DummyPipeline
   
   
   properties
      processes  % cell array of cell arrays, each entry of form {@fcn, arg1, arg2, ...}
      outputType = 'uint8'  % can be 'uint8' or 'uint16'  
   end
   
  
   
   methods
      
      function obj = PipelineModel(processArray)
         % model = PipelineModel()
         % model = PipelineModel(processArray)
         %
         % Create a PipelineModel instance, optionally passing in as an argument the ordered set of 
         % functions to apply as the pipeline (as a cell array of cell arrays). 
         %
         % Default Pipeline: 
         % (1) Demosaic
         % (2) Scale from default SensorModel.maxDN of 2^10-1 to 8-bit max
         % (3) Apply gamma of 1/2.2, to make it look like sRGB.
         % (4) Output as 8-bit.
         
         if nargin==0
            proc1 = {@PipelineModel.demosaic, 'grbg'};
            proc2 = {@PipelineModel.scale_max, 2^10-1, 255}; % defaults to match default SensorModel
            proc3 = {@PipelineModel.apply_gamma, 1/2.2, 255};
            
            processArray = {proc1, proc2, proc3};
         end
         
         % Check the inputs
         if iscell(processArray)
            for i = 1:length(processArray)
               if ~iscell(processArray{i})
                  error('Constructor input (if supplied) must be a cell array of cell arrays.')
               end
            end
            obj.processes = processArray;
         else 
            error('Constructor input (if supplied) must be a cell array of cell arrays.')
         end
            
      end
      
      
      
      function processedIm = process(obj,sensorData)
         % processedIm =  pipeline.process(sensorData)
         %
         % - - Input - -
         % sensorData : MxN sensor data array
         %
         % - - Output - -
         % processedIm : image data array, of type indicated by .outputType property. Dimensions not
         %               particularly guaranteed.
         % 
         
         for i = 1:length(obj.processes)
            fnc = obj.processes{i}{1};
            args = obj.processes{i}(2:end);
            sensorData = feval(fnc,sensorData,args{:});
         end
         
         processedIm = cast(sensorData,obj.outputType);
      end
      
      
   end
   
   
   
   methods (Static)
      
      
      function outData = demosaic(inData,bayerPhase)
         % outData = demosaic(inData,bayerPhase)
         % 
         % Apply the built-in (MATLAB) demosaicing function. Requires Image Processing Toolbox.
         % Currently, only works for values in range [0, 2^16-1]. (Conversion to integer happens
         % before demosaicing.)
         %
         % - - Inputs - - 
         % inData : image data array, MxNx1. If floating point, values should NOT be normalized 0-1.
         % bayerPhasee : string indicating Bayer CFA phase- 'grbg', 'rggb', 'bggr', or 'gbrg'
         %
         % - - Output - -
         % outData : color image data, MxNx3
         
         if ~isinteger(inData)
            inData = uint16(inData);
         end
         
         outData = demosaic(inData,bayerPhase);
         
         % Return to input type as needed
         if ~isinteger(inData)
            outData = cast(outData, class(inData));
         end
         
      end
      
      
      
      function outData = scale_max(inData,inMax,outMax)
         % outData = scale_max(inData,inMax,outMax)
         %
         % Simple scaling of the data so that the input max value (e.g. a sensor's max value) maps 
         % to another chosen one, preserving type but doing calculation on real values.
         % 
         %
         % - - Inputs - -
         % inData : image data array, any type
         % inMax : maximum (saturation) value of input data
         % outMax : maximum (saturation) value of output data
         %
         % - - Output - -
         % outData : scaled image data array, same type as input
         
         outData = cast(double(inData)/inMax*outMax, class(inData));
         
      end
      
      
      
      function outData = apply_gamma(inData,gamma,maxVal)
         % outData = apply_gamma(inData,gamma,maxVal)
         %
         % Apply gamma encoding to an image. Note that the value applied should be the reciprocal of
         % what is often called the gamma value. 
         %
         % For example, to encode an image in a sRGB-like 2.2 encoding, you actually enter the value
         % of 1/2.2.
         %
         % Data type is preserved in output, but calculation is done on type double conversion.
         %
         % - - Inputs - - 
         % inData : image data array, any size or dimension
         % gamma : power value to raise the data to
         % maxVal : the value which maps to saturation in the image data
         %
         % - - Output - -
         % outData : gamma-encoded image data, same size as input
         
         % Normalize to 1 if not already.
         if maxVal ~= 1
            origType = class(inData);
            inData = double(inData)/maxVal;
         end
   
         outData = inData.^gamma;
         
         % Undo normalization if need be
         if maxVal ~= 1
            outData = cast(outData*maxVal,origType);
         end
      end
      
   end
   
end % end classdef


