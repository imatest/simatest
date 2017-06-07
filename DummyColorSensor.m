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

classdef DummyColorSensor < SensorModel
   % A dummy sensor which just passes through data (nearly) exactly. (It does integer-ize the data.)
   %
   % Unlike the standard SensorModel, this does not reduce the 3-channel input to one-channel via
   % re-mosaicking. (This is so that the image is *really* just passed through and doesn't require
   % demosaicking which could change values.) You should make sure that any PipelineModel following
   % this expects that sort of input (i.e., does not demosaic), or use a DummyPipeline();
   
   
   methods
      
      function obj = DummyColorSensor(sensorSize,varargin)
         if nargin==1
            varargin = {};
         end
         obj = obj@SensorModel(sensorSize,varargin{:});
         
      end
      
      % Override the exposre() method to accomplish the simulation bypass.
      function dn = expose(~,radiantPower,~)
         % dn = dummy.expose(radiantPower)
         %
         % Also accepts a second 't' argument to be consistent with other SensorModels, but simply
         % ignores it.
         
         dn = uint16(radiantPower);
      end
   end
   
   
end % end classdef