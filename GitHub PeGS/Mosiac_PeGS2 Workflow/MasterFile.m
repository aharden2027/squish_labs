
%% Master file for Arno and Ashe's version of Vir's version of PeGS2
    % Please note that this program is set up to run on .png inputs

% Module Toggles
renameImages = false; % Rename unsorted images?
runParticleDetect = false; % Run Particle Detect?
runCannyAuto = false; % Run Canny Auto?
runParticleID = false; % Run Preserve Particle ID?
runCD2 = false; % Run Contact Detect?
runDiscSolve = true; % Run DiscSolve?

% Rename Images Parameters
riimageFolder = 'testdata/images_unsorted';
riimageDestination = 'testdata/images'; 
riimageFormat = '*.png'; 

%% Dimensions of Mosiac
rows = 7;
cols = 9;

%% File Parameters
fileParams = struct();
fileParams.topDir      = 'testdata';    % project root (current folder)
fileParams.imgDir      = 'images';      % folder with piece_*.png
fileParams.imgReg      = 'piece_*.png'; % glob for images
fileParams.particleDir = 'particles';   % centres from particleDetect_AA
fileParams.cannyDir    = 'canny_output';% outputs from canny_auto
fileParams.contactDir  = 'contacts';    % where contact files go
fileParams.solvedDir = 'solved'; % output directory for solved force information

%% particleDetect Parameters
pdParams = struct();
pdParams.rows = rows;
pdParams.cols = cols;
pdParams.radiusRange        = [175 285];
pdParams.objectPolarity     = 'dark';
pdParams.sensitivity        = 0.985;
pdParams.edgeThreshold      = 0.05;
pdParams.minCenterDistance  = 250;
pdParams.dtol               = 30;
pdParams.tol                = 50;
pdParams.filter             = true;
pdParams.showFigures        = true;
pdParams.clean              = true;

%% canny_auto Parameters
caParams = struct();
caParams.rows = rows;
caParams.cols = cols;
caParams.distanceThreshold = 50;
caParams.displayFigures = true;
caParams.debugMode = false;
caParams.totalImages = rows * cols;
caParams.visualizeParticles = true;
caParams.globalMap = true;

%% contactDetect2 Parameters
cdParams = struct();
cdParams.metersperpixel       = 0.007/160;  % your calibration
cdParams.fsigma               = 140;        % PE stress coefficient
cdParams.g2cal                = 100;        % g²→force calibration
cdParams.dtol                 = 10;         % neighbour distance tol (px)
cdParams.contactG2Threshold   = 0.5;        % minimal g² in contact area
cdParams.CR                   = 10;         % contact radius margin (px)
cdParams.imadjust_limits      = [0 0.65];   % contrast stretch for green ch.
cdParams.rednormal            = 2;          % red‑leak subtraction factor
cdParams.figverbose= true;                  % show figures & save JPGs


%% disc solve Parameters
dsParams = struct();
dsParams.algorithm              = 'levenberg-marquardt';  % Solver algorithm
dsParams.maxIterations          = 200;                      % Max iterations for solver
dsParams.maxFunctionEvaluations = 400;                    % Max function evaluations
dsParams.functionTolerance      = 0.01;                   % Tolerance for convergence
dsParams.scaling                = 0.5;                    % Scale of particle image
dsParams.maskradius             = 0.96;                   % Masking fraction of radius
dsParams.original               = 1;                      % Use original solver
dsParams.vectorise              = 0;                      % (future option) use vectorised solver
fitoptions = optimoptions('lsqnonlin','Algorithm',dsParams.algorithm,'MaxIter',dsParams.maxIterations,'MaxFunEvals',dsParams.maxFunctionEvaluations,'TolFun',dsParams.functionTolerance);
dsParams.fitoptions = fitoptions;
dsParams.mosaic                 = true;
dsParams.newtonizeInitial       = false;
dsParams.newtonizeOutput        = false;
dsParams.guess                  = .15;


%% Run Modules

if renameImages
    rename_images(riimageFolder, riimageDestination, rows, cols, riimageFormat);
    fprintf('Rename Images finished\n');
end

if runParticleDetect
    fprintf("\n")
    particleDetect(fileParams, pdParams, true);
    fprintf('Particle Detect finished\n');
end 

if runCannyAuto
    fprintf("\n")
    canny_auto(fileParams, caParams, true);
    fprintf('Canny Auto finished\n');
end

if runParticleID
    fprintf("\n")
    preserveParticleID(fileParams,true);
    fprintf('Preserve Particle ID finished\n');
end

if runCD2
    fprintf("\n")
    contactDetect2(fileParams, cdParams, true);
    fprintf('Contact Detect 2 finished\n');
end

if dsParams.mosaic && runDiscSolve
    fprintf("Combining Contact Files")
    contactCombine(fileParams)
    fprintf('Contact Files Combined\n')
end

if runDiscSolve
    fprintf("\n")
    diskSolve_arno(fileParams, dsParams, false)
    fprintf('Disc Solve finished\n');
end

fprintf('Process Complete!\n');
