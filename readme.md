Simatest is **Imatest**'s **sim**ulation suite. Simatest is designed to simulate exposures of a 'scene' made with a virtual camera whose parameters can be set by the user. 

Simatest is open source (GPLv3) but written in MATLAB. It requires the MATLAB Image Processing toolbox. 

[GNU Octave](https://www.gnu.org/software/octave/) is the open-source replacement to MATLAB, if you want to be completely open. It boasts drop-in compatibility with many MATLAB scripts, though we have not tested compatibility ourselves. 

Simatest makes use of the object-oriented aspects of MATLAB, which you can familiarize yourself with [here](https://www.mathworks.com/help/matlab/object-oriented-programming.html).



## What Simtest does:
Simatest is a suite for producing simulated camera exposures based on an input raster image as ground truth. 

* It can simulate lens-originated aspects of image formation *in effect only, not in cause*. That is, we simulate things such as radial geometric distortion lateral chromatic aberration only by direct application of the very models of these effects which Imatest tests for. We do not simulate the actual optical causes of these effects.

* It can simulate an exposure with a linear sensor with a very realistic noise model.

* It can apply any arbitrary, user-defined image-processing pipeline to the raw (simulated) sensor output. This can include demosaicking, scaling, color correction, etc. 



## What Simatest does not do:
Simatest does not (currently)

* slice
* dice
* work with vector inputs
* directly model light spectra
* trace rays or model geometric optics
* implement a general "planar image in front of a camera" model (with perspective distortion, etc)

It is likely that the last point will be implemented in the future. But besides that and possibly support for vector graphic inputs, it is generally out of the scope of this project to implement true optical simulations.



## Quick-start guide
Simatest works in the following fashion:

1. Create or load an image to use as the 'scene' to simulate an exposure of. 
	* The values of this base image will be intepreted as light power (per location and color channel) in units of photons/second, so scale it accordingly.
2. Create a `CameraModel` instance to image the scene. 
	* This needs to be tied to the size of the scene image, and can be created as so: `camodel = CameraModel(size(scene))`
	* The `CameraModel` instance has models for each of three components of the system: the lens, the sensor, and the processing. 
3. Create new `LensModel`, `SensorModel`, or `PipelineModel` instances with properties of your choosing and store them in the `CameraModel` as appropriate, or simply set the property values of the existing ones directly. 
	* *e.g.*, `camodel.sensorModel.gain = 2;` sets the sensor component's  electron-to-DN gain to 2.
4. Produce a simulated exposure of the scene by invoking the `CameraModel`'s `.simulate_exposure(scene,t)` method.
	* The second argument of this method is an exposure time, in seconds. An appropriate exposure time can be found by invoking the `t = camodel.find_ae_time(scene,mode)` method, which effectively acts as an auto-exposure function.
	* A composite call may look like: `exposure = camodel.simulate_exposure(scene,camodel.find_ae_time(scene,'saturation')`
5. View or save your simulated exposure! It is correctly formatted already for function like `imshow()` and `imwrite()`.



## The Scene (input data) 
Simatest uses an image data array as an input "scene" of the real world.

Currently, Simatest is designed so that the each pixel of a scene maps to a pixel of the virtual camera sensor. The digital values at each pixel location in the scene are used to represent the *radiant power in units of photons/second*.

Because of this, input data scenes should be the same resolution as the virtual camera imaging them. Note that this holds even when the lens modeling component simulate geometric distortion- it will return a distorted image of the same size (which can be read as the radiant energy falling at each pixel location on the sensor plane).


#### Color Channels
Since Simatest models do not deal with light spectra, they assume that different R, G, B color channels of the input scene are already intensity/power values relative to the sensitivities of the R, G, B filtered pixel locations of the Bayer sensor. 

These interact with the `SensorModel`'s `.qe` (quantum efficiency) property which also scales each of the input channels. 

This method allows us to use simulate the effects of different color *data* without having to simulate the *cause* of these data, e.g. an integral over wavelengths of a spectrum with a sensitivity curve (which is itself the combination of wavelength-dependent QE and color filter sensitivities). The user is urged to think about these interpretations and their ramifications on the simulations. 



#### Note on linearity
Light is linear, and so the input scene data will be interpreted as linear as well. This means that if you use, *e.g.*, an sRGB-encoded image as the base for scene data the data will be interpreted as linear, which is probably incorrect and not what you intended. If you use a `CameraModel` which applies its own gamma to an exposure of this scene, it would look "double gamma'd".

In short, input scene data should be 'linear', and it is up to the user to make sure that it is. If the image looks "right" using imshow() before being put into as scene data input (and you have a regular computer monitor), something is probably wrong. 





## `CameraModel` class
A virtual camera is represented by the `CameraModel` class. This class is essentially just a container for the models of the three sub-components-- LensModel, SensorModel, and PipelineModel-- and some control methods (such as simulating auto-exposure to determine exposure time based on a scene).

The general procedure is to instantiate a `CameraModel` object, `camodel`, populate its `.sensorModel`, `.lensModel`, and `.pipelineModel` properties appropriately, create an input scene image array, and then make a virtual exposure of it using:

`capture = camodel.simulate_exposure(sceneData, t)`

Here `t` is the exposure time for capturing this scene, just as you would need to set with a real camera. 

Just as in real life, it's necessary to tie the exposure time appropriately to the scene content- you wouldn't take a 1/4000s exposure in a low-light scene because you wouldn't get any signal, and you wouldn't take a 1s exposure in daylight because it would saturate everything.

`CameraModel` instances have a useful method, `camodel.find_ae_time(sceneData, mode)`, which will help you determine an appropriate exposure time based on the current gain setting and the brightness (data value magnitudes) of the scene. Basically, it's a camera auto-exposure method with two modes: 

* `grayworld`  (default) : find the exposure time that brings the mean raw data value (after gain, before processing) of the scene to 1/2 of the maximum 
* `saturation` : find the exposure time that brings the maximum value of the scene just to the saturation point 


Invoking the `camodel.simulate_exposure()` method manages the calls to the simulation functions of the component models. Thus, this is the main interface for actually performing the simulation and you do not need to access the methods of the subsequent classes directly, only set their properties appropriately.


## `LensModel` class
`LensModel` instances contain properties that define the effective radial distortion, lateral chromatic aberration, and lens flare (aka veiling glare) a lens may introduce. It is important to note that we simulate the observable effects of these degradations, *not* the causes. The models used are typically those which we can give a measurement of in Imatest.


#### Radial Distortion
Radial geometric disortion can be applied by a `LensModel` instance by setting the polynomial coefficients which define the distortion function in its `.distortionCoeffs` property.
This polynomial can be 3rd or 5th order, and describes the function f() such that

r\_d = f(r\_u) 

Here r\_u is the normalized, undistorted image radius (distance from center) of a point, and r\_d is the distrted version of it. Note that this function is the inverse of the one whose polynomial coefficients Imatest measures and returns- that function maps from r\_d to r\_u. 

#### Lateral Chromatic Aberration (LCA)
LCA (sometimes known as LCD, Lateral Chromatic Displacement) is defined as different radial distances of points per each color channel. Like geometric distortion, it is modeled here as radial and with a polynomial approximation (3rd or 5th order please).

Since LCA is just about relative displacement of the different color channels, it is enough to use one channel as the base and 'aberrate' the others relative to it. We use the green color channel as base, so two LCA-defining polynomials are required to describe the displacement of the other channels- red channel relative to green in the `.lcaCoeffs_rg` property and blue channel relative to green in the `.lcaCoeffs_bg` property.

Each of these is used to describe functions that make the transformation:

r\_red = f(r\_green)   
or
r\_blue = f(r\_green)


#### Lens Flare
We model lens flare as a global effect in Simatest. That means that some fraction of the light power coming in from each location is spread around to the entire image, effectively raising the floor level from 0 and reducing contrast. 

The flare model assumes that some portion of the light from each pixel gets spread evenly around the image to every other pixel. This portion is identified in `LensModel` instances by the `.flareConstant`, which should be in the range [0, 1].
   
The model thus becomes that each input value is attenuated by the flare constant (i.e., scaled to `value*(1-flareConstant)`), and then the total energy that has been 'sapped' from all locations is then summed and distributed equally to all locations. Total amount of input signal is preserved, just redistributed. 

### Default `LensModel`
The default instance of this class produced with an empty constructor essentially is a perfect lens- it has no flare, identity function distortion, and no LCA. 


## `SensorModel` class
`SensorModel` class instances represent a linear sensor with a Bayer Color Filter Array. There is a highly realistic noise model for this sensor, based on the model described in the EMVA1288 standard. The user is encouraged to refer to that (very smartly written) document [here](http://www.emva.org/standards-technology/emva-1288/), as we will not explain all of the elements in depth here. This noise model includes signal-dependent shot noise as well as a number of device-dependent additive and multiplicative sources. 

Creating a `SensorModel` instance requires a two element *size* array, [M, N], whose elements indicate the number of rows and columns, respectively, of the simulated sensor. 

Note that below we use the term 'DN' to to refer to 'digital number', the output of the analog-to-digital converter (ADC) of the sensor. This is the raw data output of the sensor. Also note that this class always produces data of type `uint16` from its simulations, regardless of what the actual range the sensor effectively has (defined by `.maxDN`). Note that this means you can't meaningfully set `.maxDN` greater than 2^16-1.


##### Noise-model related properties 
**Property** | **Value type** | **Meaning**
-------- | ---------- | -------
`.darkCurrent` | MxN double | Additive per-pixel non-uniformity during integration time, units of electrons/sec
`.noiseFloor_e` | double | Additive noise after integration (due to readout, etc), units of electrons
`.prnu` | MxN double | Multiplicative per-pixel non-uniformity relative to mean gain, unitless


##### Linear-sensor related properties
**Property** | **Value type**  | **Meaning**
-------- | ---------- | -------
`.gain` | double | electronic gain factor, units of DN/electron
`.maxDN` | integer | Maximum digital number value, e.g. 2^10-1 for a 10-bit ADC. This need not be related to a power of 2.
`.offset` | integer | Black level offset, units of DN
`.qe` | 1x3 vector | Effective sensitivity of the R, G, B channel locations, respectively, to the input, units of electrons/photons.
`.wellCapacity` | integer | Maximum number of electrons the photosensitive element can hold. Can be set to `inf`.

(Note that a sensor can produce 'saturated' output at a pixel that either hits the well capacity in electrons or hits the maxDN in electrons\*gain, whichever comes first. Note that the former *is* saturated by all reasonable definitions, though not at max output level of the sensor.)

##### Other properties
**Property** | **Value type**  | **Meaning**
-------- | ---------- | -------
`.bayerPhase` | string | Phase (orientation) of the Bayer sensor, describing the upper left (square) block of four pixels in raster order. Either 'grbg' (default), 'rggb', 'bggr', or 'gbrg'.


### Default `SensorModel`
The default instance of this class (constructed with only a sensorSize argument) is 10-bit Bayer-GRBG, unitary gain and qe, infinite well-capacity and no data offset, with no additive noise, PRNU, or dark current. 


## `PipelineModel` class
Instances of the `PipelineModel` class are the most flexible of the three components, because it is arbitrarily defined by the user. The user can construct a sequence of operations to apply to the raw data output of the `SensorModel`'s simulation, using any MATLAB function of their devising. 

The user must populate the `PipelineModel` instance's `.processes` property with a sequence of functions to apply to the data, in order. These can (and should) be functions for demosaicking, scaling, gamma compression, etc, that you might expect raw data from a sensor to be subjected to.

Each function to be applied to the data should be stored in a cell array as `processCell = {myFnc_handle, arg1, arg2, ...}`. This function will then be called during execution of the instance's `.process()` method (which is managed by the containing `CameraModel` instance's `.simulate_exposure()` method) as follows:

`dataOut = myFnc(dataIn, arg1, arg2, ...)`

You must make sure any functions you register with the pipeline follow this signature of image data array as the first argument and supplemental arguments following.

Multiple processes can be applied to the data, in order, by creating a cell array of these cell arrays, like `{processCell1, processCell2, ...}`. (Of course, you could also write one all-encompassing processing function and that takes in the raw data and produces the finished output, and register that one function with the `PipelineModel`.)

The only other aspect of `PipelineModel` instances is the `.outputType` property, which is a string that can be set to either `'uint8'` or `'uint16'`. This indicates the final data type of the output image, and invokes a casting as that type after the final process defined in the set of `.processes`.

#### Example processing functions
Some useful examples of processing functions are included as `PipelineModel` class static methods. These include: 

	outData = PipelineModel.demosaic(inData,bayerPhase);            % Apply MATLAB Image Processing toolbox demosiacing
	outData = PipelineModel.scale_max(inData,inMax,outMax);         % Re-scale the data
	outData = PipelineModel.apply_gamma(inData,gamma,maxVal);       % Apply a gamma power encoding to data

### Default `PipelineModel`
The default pipeline processing is tied to the default `SensorModel`, described above, in order to make simple implementations work nicely. It simply demosaics the image, scales from the 10-bit data to 8-bit data, and applies an sRGB-like gamma of 2.2, and finally outputs an 8-bit image. 



## Dummy Component Models
A common task is to simulate only one aspect of this entire camera-modeling process. For example, if you only want to apply geometric distortion or LCA on an image using a certain lens model but don't want to make a fake 'exposure' of it or process it in other ways.

You can shortcut component models of the `CameraModel` with 'dummy instances'. These typically just have overridden simulation methods which pass the data through untouched.

The available Dummy models ready for instantiation are:

* `DummyLens` : Does nothing (very similar to the default `LensModel` implementation, but faster to run)
* `DummyBayerSensor` : only mosaics the 3-channel data from the lens sensor and converts to `uint16`
* `DummyColorsensor` : does nothing to 3-channel data from the lens simulation except convert to `uint16`. Note that any `PipelineModel` that is to follow this should be prepared for this, since it is atypical, and not assume the output is 1-channel like from most `SensorModel`s. (Note: A `DummyPipeline` meets this criterion.)
* `DummyPipeline`    : does nothing to the data, outputs it as `uint8`



## Example use cases
These assume you have a file in your working directory called 'linear_test_im.png'. As the name implies, and as indicated above, it should be linear (*i.e.* not gamma encoded).

Note that this is easy to create from a standard sRGB 8-bit image as follows:

	im = imread('my_favorite_image.jpg');
	im = (double(im)/255).^(2.2); 		% simple power approximation to actual sRGB encoding
	imwrite(im,'linear_test_im.png')


## Bracket exposure times
The following will load an image to use as a scene, create a default `CameraModel` to image it, and bracket the exposure times around the auto-exposure-suggested exposure time. This changes the amount of  integrated light falling on the sensor, and thus the exposure. 

The results are shown in a new figure window.

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
	


## Bracket gain while maintaining exposure
The following brackets the sensor gain (proportional to ISO speed, but defined in terms of DN/electron) while also changing the exposure time to keep the overall "exposure" level constant. Note that this has the practical effect of more effective noise in the image.

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



## Simulate raw sensor data
If we want to test measurements from raw sensor data, or a demosaicking algorithm, etc, we can just instantiate a dummy pipeline module so that we get out the raw data from the sensor as is (type `uint16`).

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




## Simulating only LCA on a real image
Sometimes we just want to simulate a degradation effect on a real image. For example, for studying subjective image quality loss due to LCA according to user ratings, we would want to apply controlled, known amounts of LCA to real images. This can be done by appropriately setting the parameters of the `LensModel` and using dummy components for the sensor and pipeline.

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






