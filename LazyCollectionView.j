
var HORIZONTAL_MARGIN = 2;

@implementation CPScrollView(visibleRect)
- (CGRect)documentVisibleRect
 {
    return [_documentView visibleRect];
 }
@end



@implementation LazyCollectionView : CPCollectionView
{
    CPIndexSet  _displayedIndexes;
    BOOL        _needsFullDisplay;
}


- (void)_init
{
	[super _init]
    _displayedIndexes = [CPIndexSet indexSet];

}

- (void)resizeSubviewsWithOldSize:(CGSize)oldBoundsSize
{
    // Desactivate subviews autoresizing
}

- (void)resizeWithOldSuperviewSize:(CGSize)oldBoundsSize
{
    if (_lockResizing)
        return;

    _lockResizing = YES;
    _needsFullDisplay = YES;
    [self tile];

    _lockResizing = NO;
}

- (void)tile
{
    [self tileIfNeeded:!_uniformSubviewsResizing];
}


/* @ignore */
- (void)_reloadContentCachingRemovedItems:(BOOL)shouldCache
{
    // Remove current views
    [_displayedIndexes enumerateIndexesUsingBlock:function(idx, stop)
    {
        var item = _items[idx];

        if (!item)
            return;

        [[item view] removeFromSuperview];
        [item setSelected:NO];

        if (shouldCache)
            _cachedItems.push(item);
    }];

    _items = [];
    _displayedIndexes = [CPIndexSet indexSet];

    if (!_itemPrototype)
        return;

    [self tileIfNeeded:NO];
}
- (void)_computeGridWithSize:(CGSize)aSuperviewSize count:(Function)countRef
{
    var width               = aSuperviewSize.width,
        height              = aSuperviewSize.height,
        itemSize            = CGSizeMakeCopy(_minItemSize),
        maxItemSizeWidth    = _maxItemSize.width,
        maxItemSizeHeight   = _maxItemSize.height,
        itemsCount          = [_content count],
        numberOfRows,
        numberOfColumns;

    numberOfColumns = FLOOR(width / itemSize.width);

    if (maxItemSizeWidth == 0)
        numberOfColumns = MIN(numberOfColumns, _maxNumberOfColumns);

    if (_maxNumberOfColumns > 0)
        numberOfColumns = MIN(MIN(_maxNumberOfColumns, itemsCount), numberOfColumns);

    numberOfColumns = MAX(1.0, numberOfColumns);

    itemSize.width = FLOOR(width / numberOfColumns);

    if (maxItemSizeWidth > 0)
    {
        itemSize.width = MIN(maxItemSizeWidth, itemSize.width);

        if (numberOfColumns == 1)
            itemSize.width = MIN(maxItemSizeWidth, width);
    }

    numberOfRows = CEIL(itemsCount / numberOfColumns);

    if (_maxNumberOfRows > 0)
        numberOfRows = MIN(numberOfRows, _maxNumberOfRows);

    height = MAX(height, numberOfRows * (_minItemSize.height + _verticalMargin));

    var itemSizeHeight = FLOOR(height / numberOfRows);

    if (maxItemSizeHeight > 0)
        itemSizeHeight = MIN(itemSizeHeight, maxItemSizeHeight);

    _itemSize        = CGSizeMake(MAX(_minItemSize.width, itemSize.width), MAX(_minItemSize.height, itemSizeHeight));
    _storedFrameSize = CGSizeMake(MAX(width, _minItemSize.width), height);
    _numberOfColumns = numberOfColumns;
    _numberOfRows    = numberOfRows;
    countRef(MIN(itemsCount, numberOfColumns * numberOfRows));
}

- (void)tileIfNeeded:(BOOL)lazyFlag
{
    var frameSize           = [[self superview] frameSize],
        count               = 0,
        oldNumberOfColumns  = _numberOfColumns,
        oldNumberOfRows     = _numberOfRows,
        oldItemSize         = _itemSize;

    // No need to tile if we are not yet placed in the view hierarchy.
    if (!frameSize)
        return;

    [self _updateMinMaxItemSizeIfNeeded];

    [self _computeGridWithSize:frameSize count:@ref(count)];

    [self setFrameSize:_storedFrameSize];

    if (!lazyFlag ||
        _numberOfColumns !== oldNumberOfColumns ||
        _numberOfRows    !== oldNumberOfRows ||
        !CGSizeEqualToSize(_itemSize, oldItemSize))
    {
        var indexes = [self _indexesToDisplay];

        if (_needsFullDisplay)
        {
            [indexes addIndexes:_displayedIndexes];
            _needsFullDisplay = NO;
        }
        else
            [indexes removeIndexes:_displayedIndexes];

        [self displayItemsAtIndexes:indexes frameSize:_storedFrameSize itemSize:_itemSize columns:_numberOfColumns rows:_numberOfRows count:count];
    }
}


- (void) superviewFrameChanged:(CPNotification)aNotification
{
    var indexes = [self _indexesToDisplay];
    [indexes removeIndexes:_displayedIndexes];

    if (![indexes count])
        return;

    [self displayItemsAtIndexes:indexes frameSize:_storedFrameSize itemSize:_itemSize columns:_numberOfColumns rows:_numberOfRows count:[_content count]];

}
- (CPCollectionViewItem)itemAtIndex:(CPInteger)anIndex
{

    var item = _items[anIndex];

    if (!item)
    {
        if(![_content count]) return nil;

        item = [self newItemForRepresentedObject:[_content objectAtIndex:anIndex]];
        _items[anIndex] = item;
    }

    return item;
}


- (CPIndexSet)_indexesToDisplay
{
    var visibleRect = [[self superview] documentVisibleRect],
        startIndex = [self _indexAtPoint:visibleRect.origin sloppy:YES];

    if (startIndex === CPNotFound)
        return [CPIndexSet indexSet];

    var endIndex = [self _indexAtPoint:CGPointMake(CGRectGetMaxX(visibleRect), CGRectGetMaxY(visibleRect)) sloppy:YES];

    if (endIndex === CPNotFound)
        endIndex = [_content count] - 1;

    return [CPIndexSet indexSetWithIndexesInRange:CPMakeRange(startIndex,(endIndex - startIndex + 1))];
}

- (void)displayItemsAtIndexes:(CPIndexSet)itemIndexes frameSize:(CGSize)aFrameSize itemSize:(CGSize)anItemSize columns:(CPInteger)numberOfColumns rows:(CPInteger)numberOfRows count:(CPInteger)displayCount
{
    CPLog.debug("DISPLAY ITEMS " + itemIndexes);
    _horizontalMargin = _uniformSubviewsResizing ? FLOOR((aFrameSize.width - numberOfColumns * anItemSize.width) / (numberOfColumns + 1)) : HORIZONTAL_MARGIN;

    var xOffset = anItemSize.width + _horizontalMargin,
        yOffset = anItemSize.height + _verticalMargin;

    [itemIndexes enumerateIndexesUsingBlock:function(idx, stop)
    {
        CPLog.debug("Display Item " + idx);
        var item = [self itemAtIndex:idx],
            view = [item view];

        if (idx >= displayCount)
        {
            [view setFrameOrigin:CGPointMake(-anItemSize.width, -anItemSize.height)];
            return;
        }

        var pos = idx / numberOfColumns,
            floor = FLOOR(pos),
            remaining = (pos - floor) * numberOfColumns;

        var x = _horizontalMargin + xOffset * remaining,
            y = _verticalMargin + yOffset * floor;

        [view setFrame:CGRectMake(x, y, anItemSize.width, anItemSize.height)];

        if (![view superview])
        {
            CPLog.debug("Add Item view " + idx);
            [self addSubview:view];
            [_displayedIndexes addIndex:idx];
        }
    }];
}

- (int)_indexAtPoint:(CGPoint)thePoint sloppy:(BOOL) sloppyFlag
{
    var column = FLOOR(thePoint.x / (_itemSize.width + _horizontalMargin));

    if (sloppyFlag)
       column = MIN(_numberOfColumns - 1, column);

    if (column < _numberOfColumns)
    {
        var row = FLOOR(thePoint.y / (_itemSize.height + _verticalMargin));

        if (row < _numberOfRows || sloppyFlag)
            return MIN(row * _numberOfColumns + column, [_content count] - 1);
    }
   return CPNotFound;
}

- (int)_indexAtPoint:(CGPoint)thePoint
{
    return [self _indexAtPoint:thePoint sloppy:NO];
}
- (void)viewWillMoveToSuperview:(CPView)aView
{
    [super viewWillMoveToSuperview:aView];

    var superview = [self superview],
        defaultCenter = [CPNotificationCenter defaultCenter];

    [defaultCenter
            removeObserver:self
                      name:CPViewFrameDidChangeNotification
                    object:superview];

     [defaultCenter
            removeObserver:self
                      name:CPViewBoundsDidChangeNotification
                    object:superview];

    if ([aView isKindOfClass:[CPClipView class]])
    {
        [aView setPostsFrameChangedNotifications:YES];
        [aView setPostsBoundsChangedNotifications:YES];

        [defaultCenter
            addObserver:self
               selector:@selector(superviewFrameChanged:)
                   name:CPViewFrameDidChangeNotification
                 object:aView];

        [defaultCenter
            addObserver:self
               selector:@selector(superviewFrameChanged:)
                   name:CPViewBoundsDidChangeNotification
                 object:aView];

    }
}





@end
