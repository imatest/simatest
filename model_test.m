%% Vary exposure around ideal for a given gain

clear all,clc,close all, clear classes

scene = imread('linear_test_im.png'); % Load an image to use as the 'scene'
camodel = CameraModel(size(scene)); % Instantiate a virtual camera for this scene, using default settings 

tOpt = camodel.find_ae_time(scene,'saturation'); % Find auto-exposure suggested exposure time
bracketStops = [-2 -1 0 1]; % set of exposures in stops) relative to ideal exposure we want to explore

figure
for i = 1:length(bracketStops)
   t = tOpt*2^(bracketStops(i));  % Compute exposure time for this bracketed exposure
   simulated = camodel.simulate_exposure(scene,t);   % Simulate the exposure
   subplot(2,2,i)
   imshow(simulated)
end

%% Vary ISO

clear all,clc,close all, clear classes

scene = imread('linear_test_im.png'); % Load an image to use as the 'scene'
camodel = CameraModel(size(scene)); % virtual camera with default setting of sensorModel.gain = 1

gains = [0.25, 1, 4, 16]; % gain levels (DN/electrion) we want to explore

figure
for i = 1:length(gains)
   camodel.sensorModel.gain = gains(i);     % Set gain to chosen level
   t = camodel.find_ae_time(scene,'saturation'); % Find suggested exposure time for this gain level
   simulated = camodel.simulate_exposure(scene,t);   % Simulate the exposure
   subplot(2,2,i)
   imshow(simulated)
end


%% RAW data
scene = imread('linear_test_im.png'); % Load an image to use as the 'scene'
camodel = CameraModel(size(scene));

camodel.pipelineModel = DummyPipeline(); % Use a pipeline that just passes data through

% Default output of dummy pipeline is uint8, but we don't want to truncate uint16 data from the 
% SensorModel, so overwrite the .outputType property.
camodel.pipelineModel.outputType = 'uint16';

simulated = camodel.simulate_exposure(scene, camodel.find_ae_time(scene)); % uses default AE mode 'grayworld'

% We must scale the output image for viewing, since the default SensorModel puts out 10-bit data in
% a 16-bit format.
figure
imshow(simulated,[0, 2^10-1]) 


%% Just LCA on a real image
scene = imread('real_world_im.jpg'); % Load a non-simulated, sRGB image as the 'scene'
camodel = CameraModel(size(scene));

% Set the LensModel's LCA parameters, overwriting the default values of zero polynomials
camodel.lensModel.lcaCoeffs_bg = [-0.01,0,0.02,0];
camodel.lensModel.lcaCoeffs_rg = [0.03,0,-0.005,0];

% Use a dummy color sensor to pass through all channels, cf dummy bayer sensor
camodel.sensorModel = DummyColorSensor(size(scene)); 
camodel.pipelineModel = DummyPipeline();

% Note: exposure time argument is not actually used by a DummySensor
simulated = camodel.simulate_exposure(scene,1);

figure,imshow(simulated)


