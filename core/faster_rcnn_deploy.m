function net = faster_rcnn_deploy(srcPath, destPath, numClasses)
% FASTER_RCNN_DEPLOY deploys a FASTER_RCNN model for evaluation
%   NET = FASTER_RCNN_DEPLOY(SRCPATH, DESTPATH, NUMCLASSES) configures
%   a Faster-RCNN model to perform evaluation.  THis process involves
%   removing the loss layers used during training and adding 
%   a combination of a transpose softmax with a detection
%   layer to compute network predictions
%
% Copyright (C) 2017 Samuel Albanie
% All rights reserved.
%
% This file is part of the VLFeat library and is made available under
% the terms of the BSD license (see the COPYING file).

tmp = load(srcPath) ; 
out = Layer.fromCompiledNet(tmp.net) ; rpn = out{1} ; frcnn = out{2} ;

% modify network to use RPN for predictions at test time
frcnn.find('proposals', 1).inputs{7} = 300 ; % num proposals
frcnn.find('proposals', 1).inputs{9} = 6000 ; % pre-NMS top N
frcnn.find('roi_pool5',1).inputs{2} = frcnn.find('proposals',1) ;

% fix names from old config
map = {{'proposals', 'proposal'}, {'imInfo', 'im_info'}} ;
for ii = 1:numel(map)
  pair = map{ii} ; old = pair{1} ; new = pair{2} ;
  if ~isempty(frcnn.find(old)), frcnn.find(old, 1).name = new ; end
end

% set outputs
bbox_pred = frcnn.find('bbox_pred', 1) ;
cls_score = frcnn.find('cls_score', 1) ;

% normalze to probabilities
largs = {'name', 'cls_prob', 'numInputDer', 0} ;
cls_prob = Layer.create(@vl_nnsoftmax, {cls_score}, largs{:}) ;
net = Net(cls_prob, bbox_pred) ;

outDir = fileparts(destPath) ;
if ~exist(outDir, 'dir'), mkdir(outDir) ; end

net.meta.backgroundClass = 1 ; 
net = net.saveobj() ; 
save(destPath, '-struct', 'net') ;